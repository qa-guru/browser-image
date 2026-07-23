// Command devtools-proxy is a tiny static CDP reverse proxy that lets Selenoid's
// hub reach a Chromium DevTools endpoint on a FIXED container port (7070) even
// though chromedriver launches Chrome with --remote-debugging-port=0, so the
// browser picks a RANDOM ephemeral port for every session.
//
// The proxy is self-sufficient — it needs no cooperation from the browser
// wrapper:
//   - Port discovery: it reads the browser's own DevToolsActivePort file (the
//     same mechanism chromedriver uses), located via /proc (the running browser
//     process' --user-data-dir) with a /tmp glob fallback.
//   - Origin: it strips the inbound Origin header before dialing the browser, so
//     Chrome 111+ accepts the CDP websocket without --remote-allow-origins.
//   - Host: it rewrites Host to loopback to satisfy Chrome's DNS-rebinding guard.
//
// Contract expected by the hub (see selenoid har.go / selenoid.go):
//   - ws  /page        -> current page target  (hub-HAR: ws://<host:7070>/page)
//   - ws  /            -> browser target       (se:cdp / /devtools/<id>/)
//   - ws  /browser     -> browser target       (alias for "/")
//   - http /json*      -> passthrough to the browser DevTools HTTP API
//
// Pure standard library so it cross-compiles to a small static binary for both
// amd64 (Chrome-for-Testing) and arm64 (Debian chromium).
package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	listenAddr = ":7070"
	loopback   = "127.0.0.1"

	// Target discovery is best-effort with a short retry window: the hub may
	// connect the instant a session is created, a hair before the browser has
	// written DevToolsActivePort / opened its first page target.
	discoverAttempts = 40
	discoverDelay    = 250 * time.Millisecond
	httpTimeout      = 3 * time.Second
)

// ---------------------------------------------------------------------------
// Debug-port discovery
// ---------------------------------------------------------------------------

// readDebugPort returns the browser's current remote-debugging port.
//
// Resolution order:
//  1. DEVTOOLS_PORT_FILE (explicit hint / tests), if it holds a real port.
//  2. The running browser process' <user-data-dir>/DevToolsActivePort (via /proc).
//  3. A /tmp/*/DevToolsActivePort glob fallback (newest wins).
func readDebugPort() (string, error) {
	if pf := strings.TrimSpace(os.Getenv("DEVTOOLS_PORT_FILE")); pf != "" {
		if b, err := os.ReadFile(pf); err == nil {
			if p := strings.TrimSpace(string(b)); p != "" && p != "0" {
				return p, nil
			}
		}
	}
	if p := portFromProc(); p != "" {
		return p, nil
	}
	if p := portFromTmpGlob(); p != "" {
		return p, nil
	}
	return "", errors.New("no live devtools port found")
}

// portFromDevToolsActivePort reads the first line (the port) of a
// DevToolsActivePort file. The file's second line holds the browser ws path.
func portFromDevToolsActivePort(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	line := string(b)
	if i := strings.IndexAny(line, "\r\n"); i >= 0 {
		line = line[:i]
	}
	line = strings.TrimSpace(line)
	if _, err := strconv.Atoi(line); err != nil || line == "0" {
		return ""
	}
	return line
}

// portFromProc finds the main browser process (has --remote-debugging-port but
// not --type=, which marks child/renderer processes), extracts its
// --user-data-dir and reads DevToolsActivePort from there.
func portFromProc() string {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return ""
	}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		if _, err := strconv.Atoi(e.Name()); err != nil {
			continue
		}
		raw, err := os.ReadFile(filepath.Join("/proc", e.Name(), "cmdline"))
		if err != nil {
			continue
		}
		args := strings.Split(string(bytes.TrimRight(raw, "\x00")), "\x00")
		var isBrowser, isChild bool
		var userDataDir string
		for _, a := range args {
			switch {
			case strings.HasPrefix(a, "--remote-debugging-port"):
				isBrowser = true
			case strings.HasPrefix(a, "--type="):
				isChild = true
			case strings.HasPrefix(a, "--user-data-dir="):
				userDataDir = strings.TrimPrefix(a, "--user-data-dir=")
			}
		}
		if !isBrowser || isChild || userDataDir == "" {
			continue
		}
		if p := portFromDevToolsActivePort(filepath.Join(userDataDir, "DevToolsActivePort")); p != "" {
			return p
		}
	}
	return ""
}

// portFromTmpGlob is a fallback for the (rare) case where /proc discovery fails
// but the browser wrote DevToolsActivePort under a scoped dir in /tmp.
func portFromTmpGlob() string {
	matches, err := filepath.Glob("/tmp/*/DevToolsActivePort")
	if err != nil || len(matches) == 0 {
		return ""
	}
	sort.Slice(matches, func(i, j int) bool {
		fi, _ := os.Stat(matches[i])
		fj, _ := os.Stat(matches[j])
		if fi == nil || fj == nil {
			return false
		}
		return fi.ModTime().After(fj.ModTime())
	})
	for _, m := range matches {
		if p := portFromDevToolsActivePort(m); p != "" {
			return p
		}
	}
	return ""
}

// ---------------------------------------------------------------------------
// CDP target resolution
// ---------------------------------------------------------------------------

func devtoolsBase(port string) string {
	return "http://" + net.JoinHostPort(loopback, port)
}

// wsPath extracts the path (with query, if any) from a CDP webSocketDebuggerUrl
// such as "ws://127.0.0.1:38001/devtools/page/ABCD". The host is discarded: we
// always dial loopback ourselves.
func wsPath(raw string) (string, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return "", fmt.Errorf("parse webSocketDebuggerUrl %q: %w", raw, err)
	}
	if u.Path == "" {
		return "", fmt.Errorf("webSocketDebuggerUrl %q has no path", raw)
	}
	if u.RawQuery != "" {
		return u.Path + "?" + u.RawQuery, nil
	}
	return u.Path, nil
}

func httpGetJSON(rawURL string, v any) error {
	client := &http.Client{Timeout: httpTimeout}
	resp, err := client.Get(rawURL)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("GET %s: status %d", rawURL, resp.StatusCode)
	}
	return json.NewDecoder(resp.Body).Decode(v)
}

type cdpTarget struct {
	Type                 string `json:"type"`
	WebSocketDebuggerUrl string `json:"webSocketDebuggerUrl"`
}

// resolvePageWS discovers the websocket path of the first page target.
func resolvePageWS(port string) (string, error) {
	var targets []cdpTarget
	if err := httpGetJSON(devtoolsBase(port)+"/json", &targets); err != nil {
		return "", err
	}
	for _, t := range targets {
		if t.Type == "page" && t.WebSocketDebuggerUrl != "" {
			return wsPath(t.WebSocketDebuggerUrl)
		}
	}
	return "", errors.New("no page target with a websocket url found")
}

// resolveBrowserWS discovers the browser-level websocket path (se:cdp).
func resolveBrowserWS(port string) (string, error) {
	var v struct {
		WebSocketDebuggerUrl string `json:"webSocketDebuggerUrl"`
	}
	if err := httpGetJSON(devtoolsBase(port)+"/json/version", &v); err != nil {
		return "", err
	}
	if v.WebSocketDebuggerUrl == "" {
		return "", errors.New("/json/version has no browser websocket url")
	}
	return wsPath(v.WebSocketDebuggerUrl)
}

// discover reads the live debug port and resolves a websocket target path,
// retrying briefly to absorb the session-startup race.
func discover(resolve func(port string) (string, error)) (port, target string, err error) {
	for attempt := 0; attempt < discoverAttempts; attempt++ {
		port, err = readDebugPort()
		if err == nil {
			target, err = resolve(port)
			if err == nil {
				return port, target, nil
			}
		}
		time.Sleep(discoverDelay)
	}
	return "", "", err
}

// ---------------------------------------------------------------------------
// Reverse proxying
// ---------------------------------------------------------------------------

// proxyWS resolves a websocket target on the live debug port and reverse-proxies
// the connection (httputil.ReverseProxy transparently handles the HTTP Upgrade).
func proxyWS(w http.ResponseWriter, r *http.Request, resolve func(port string) (string, error)) {
	port, target, err := discover(resolve)
	if err != nil {
		log.Printf("[devtools-proxy] %s: discovery failed: %v", r.URL.Path, err)
		http.Error(w, "devtools endpoint unavailable", http.StatusBadGateway)
		return
	}
	upstream := &url.URL{Scheme: "http", Host: net.JoinHostPort(loopback, port)}
	rp := httputil.NewSingleHostReverseProxy(upstream)
	rp.Director = func(req *http.Request) {
		req.URL.Scheme = upstream.Scheme
		req.URL.Host = upstream.Host
		req.URL.Path = target
		req.URL.RawQuery = ""
		// Chrome validates Host against loopback (DNS-rebinding guard); the
		// inbound Host is the container IP, so rewrite it.
		req.Host = upstream.Host
		// Drop Origin so Chrome 111+ accepts the CDP handshake without needing
		// --remote-allow-origins on the browser command line.
		req.Header.Del("Origin")
	}
	rp.ErrorHandler = func(w http.ResponseWriter, _ *http.Request, e error) {
		log.Printf("[devtools-proxy] proxy error for %s: %v", target, e)
		http.Error(w, "devtools proxy error", http.StatusBadGateway)
	}
	rp.ServeHTTP(w, r)
}

// proxyJSON passes the browser DevTools HTTP API (/json, /json/version,
// /json/protocol, /json/list) straight through.
func proxyJSON(w http.ResponseWriter, r *http.Request) {
	port, err := readDebugPort()
	if err != nil {
		log.Printf("[devtools-proxy] %s: %v", r.URL.Path, err)
		http.Error(w, "devtools endpoint unavailable", http.StatusBadGateway)
		return
	}
	upstream := &url.URL{Scheme: "http", Host: net.JoinHostPort(loopback, port)}
	rp := httputil.NewSingleHostReverseProxy(upstream)
	baseDirector := rp.Director
	rp.Director = func(req *http.Request) {
		baseDirector(req)
		req.Host = upstream.Host
	}
	rp.ErrorHandler = func(w http.ResponseWriter, _ *http.Request, e error) {
		log.Printf("[devtools-proxy] json proxy error: %v", e)
		http.Error(w, "devtools proxy error", http.StatusBadGateway)
	}
	rp.ServeHTTP(w, r)
}

func isWebSocketUpgrade(r *http.Request) bool {
	return strings.EqualFold(r.Header.Get("Upgrade"), "websocket")
}

func newMux() *http.ServeMux {
	mux := http.NewServeMux()

	// Page-level CDP target — used by hub-HAR (ws://<host:7070>/page).
	mux.HandleFunc("/page", func(w http.ResponseWriter, r *http.Request) {
		proxyWS(w, r, resolvePageWS)
	})
	// Browser-level CDP target — used by se:cdp and /devtools/<id>/browser.
	mux.HandleFunc("/browser", func(w http.ResponseWriter, r *http.Request) {
		proxyWS(w, r, resolveBrowserWS)
	})
	// Browser DevTools HTTP API passthrough.
	mux.HandleFunc("/json", proxyJSON)
	mux.HandleFunc("/json/", proxyJSON)
	// "/" is the upstream alias for the browser target (se:cdp / /devtools/<id>/).
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/" && isWebSocketUpgrade(r) {
			proxyWS(w, r, resolveBrowserWS)
			return
		}
		if r.URL.Path == "/" {
			// Plain HTTP probe (e.g. readiness): report proxy liveness without
			// requiring a running browser session.
			w.Header().Set("Content-Type", "text/plain; charset=utf-8")
			_, _ = w.Write([]byte("devtools-proxy ok\n"))
			return
		}
		http.NotFound(w, r)
	})
	return mux
}

func main() {
	srv := &http.Server{Addr: listenAddr, Handler: newMux()}
	log.Printf("[devtools-proxy] listening on %s", listenAddr)
	if err := srv.ListenAndServe(); err != nil {
		log.Fatalf("[devtools-proxy] server error: %v", err)
	}
}
