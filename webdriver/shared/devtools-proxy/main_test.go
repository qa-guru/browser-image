package main

import (
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWsPath(t *testing.T) {
	cases := map[string]string{
		"ws://127.0.0.1:38001/devtools/page/ABCD":   "/devtools/page/ABCD",
		"ws://127.0.0.1:38001/devtools/browser/XYZ": "/devtools/browser/XYZ",
		"ws://localhost:9/devtools/page/A?foo=bar":  "/devtools/page/A?foo=bar",
	}
	for in, want := range cases {
		got, err := wsPath(in)
		if err != nil {
			t.Fatalf("wsPath(%q) error: %v", in, err)
		}
		if got != want {
			t.Errorf("wsPath(%q) = %q, want %q", in, got, want)
		}
	}
	if _, err := wsPath("://bad url"); err == nil {
		t.Errorf("expected error for malformed url")
	}
}

func TestPortFromDevToolsActivePort(t *testing.T) {
	dir := t.TempDir()
	// Real DevToolsActivePort layout: line1 = port, line2 = browser ws path.
	good := filepath.Join(dir, "DevToolsActivePort")
	if err := os.WriteFile(good, []byte("45303\n/devtools/browser/abc\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := portFromDevToolsActivePort(good); got != "45303" {
		t.Errorf("port = %q, want 45303", got)
	}
	// A port of 0 (auto-assign, not yet resolved) must be rejected.
	zero := filepath.Join(dir, "zero")
	_ = os.WriteFile(zero, []byte("0\n"), 0o644)
	if got := portFromDevToolsActivePort(zero); got != "" {
		t.Errorf("expected empty for port 0, got %q", got)
	}
	if got := portFromDevToolsActivePort(filepath.Join(dir, "missing")); got != "" {
		t.Errorf("expected empty for missing file, got %q", got)
	}
}

// fakeDevtoolsOnPort binds a fake browser DevTools HTTP API on 127.0.0.1:<port>.
func fakeDevtoolsOnPort(t *testing.T, port string) *httptest.Server {
	t.Helper()
	mux := http.NewServeMux()
	mux.HandleFunc("/json/version", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"webSocketDebuggerUrl":"ws://127.0.0.1:` + port + `/devtools/browser/BROWSER"}`))
	})
	mux.HandleFunc("/json", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`[{"type":"page","webSocketDebuggerUrl":"ws://127.0.0.1:` + port + `/devtools/page/PAGE1"}]`))
	})
	l, err := net.Listen("tcp", net.JoinHostPort(loopback, port))
	if err != nil {
		t.Skipf("cannot bind 127.0.0.1:%s: %v", port, err)
	}
	ts := &httptest.Server{Listener: l, Config: &http.Server{Handler: mux}}
	ts.Start()
	return ts
}

func freePort(t *testing.T) string {
	t.Helper()
	l, err := net.Listen("tcp", net.JoinHostPort(loopback, "0"))
	if err != nil {
		t.Fatal(err)
	}
	_, port, _ := net.SplitHostPort(l.Addr().String())
	_ = l.Close()
	return port
}

func TestResolvePageAndBrowser(t *testing.T) {
	port := freePort(t)
	ts := fakeDevtoolsOnPort(t, port)
	defer ts.Close()

	pagePath, err := resolvePageWS(port)
	if err != nil {
		t.Fatalf("resolvePageWS: %v", err)
	}
	if pagePath != "/devtools/page/PAGE1" {
		t.Errorf("page path = %q", pagePath)
	}
	browserPath, err := resolveBrowserWS(port)
	if err != nil {
		t.Fatalf("resolveBrowserWS: %v", err)
	}
	if browserPath != "/devtools/browser/BROWSER" {
		t.Errorf("browser path = %q", browserPath)
	}
}

func TestProxyJSONPassthrough(t *testing.T) {
	port := freePort(t)
	ts := fakeDevtoolsOnPort(t, port)
	defer ts.Close()

	// Point discovery at the fake via the explicit port-file hint.
	pf := filepath.Join(t.TempDir(), "devtools.port")
	_ = os.WriteFile(pf, []byte(port), 0o644)
	t.Setenv("DEVTOOLS_PORT_FILE", pf)

	req := httptest.NewRequest(http.MethodGet, "/json/version", nil)
	rec := httptest.NewRecorder()
	proxyJSON(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("proxyJSON status = %d", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "webSocketDebuggerUrl") {
		t.Errorf("unexpected body: %s", rec.Body.String())
	}
}

func TestReadDebugPortFromHint(t *testing.T) {
	pf := filepath.Join(t.TempDir(), "devtools.port")
	_ = os.WriteFile(pf, []byte("51234\n"), 0o644)
	t.Setenv("DEVTOOLS_PORT_FILE", pf)
	got, err := readDebugPort()
	if err != nil || got != "51234" {
		t.Fatalf("readDebugPort() = %q, %v; want 51234", got, err)
	}

	// A hint of 0 must be ignored (falls through to /proc + glob, which find
	// nothing in the test env).
	_ = os.WriteFile(pf, []byte("0\n"), 0o644)
	if _, err := readDebugPort(); err == nil {
		t.Errorf("expected error when hint is 0 and no browser is running")
	}
}

func TestRootHTTPProbe(t *testing.T) {
	mux := newMux()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "devtools-proxy ok") {
		t.Errorf("root probe: code=%d body=%q", rec.Code, rec.Body.String())
	}
}
