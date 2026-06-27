# Playwright browser images for Selenoid

Docker-образы browser nodes для [qa-guru/selenoid](https://github.com/qa-guru/selenoid). Hub поднимает их по запросу и проксирует Playwright WebSocket на `/playwright/{browser}/{version}`.

[![Publish](https://github.com/qa-guru/playwright-image/workflows/publish/badge.svg)](https://github.com/qa-guru/playwright-image/actions?query=workflow%3Apublish)
[![Release](https://img.shields.io/github/release/qa-guru/playwright-image.svg)](https://github.com/qa-guru/playwright-image/releases/latest)

[![Docker Pulls Chromium](https://img.shields.io/docker/pulls/qaguru/playwright-chromium.svg?label=chromium)](https://hub.docker.com/r/qaguru/playwright-chromium)
[![Docker Pulls Firefox](https://img.shields.io/docker/pulls/qaguru/playwright-firefox.svg?label=firefox)](https://hub.docker.com/r/qaguru/playwright-firefox)
[![Docker Pulls WebKit](https://img.shields.io/docker/pulls/qaguru/playwright-webkit.svg?label=webkit)](https://hub.docker.com/r/qaguru/playwright-webkit)
[![Docker Pulls Chrome](https://img.shields.io/docker/pulls/qaguru/playwright-chrome.svg?label=chrome)](https://hub.docker.com/r/qaguru/playwright-chrome)
[![Docker Pulls Edge](https://img.shields.io/docker/pulls/qaguru/playwright-msedge.svg?label=msedge)](https://hub.docker.com/r/qaguru/playwright-msedge)

| | |
|---|---|
| **GitHub** | [qa-guru/playwright-image](https://github.com/qa-guru/playwright-image) |
| **Docker Hub** | [`qaguru/playwright-chromium`](https://hub.docker.com/r/qaguru/playwright-chromium), [`playwright-firefox`](https://hub.docker.com/r/qaguru/playwright-firefox), [`playwright-webkit`](https://hub.docker.com/r/qaguru/playwright-webkit), [`playwright-chrome`](https://hub.docker.com/r/qaguru/playwright-chrome), [`playwright-msedge`](https://hub.docker.com/r/qaguru/playwright-msedge) |

## Роль в экосистеме

Это **не hub** — отдельные контейнеры с Playwright `launchServer`, VNC и Xvfb. Hub [qa-guru/selenoid](https://github.com/qa-guru/selenoid) читает `browsers.json`, стартует нужный образ и проксирует WebSocket клиента.

```
Playwright test  ──►  selenoid hub  ──►  qaguru/playwright-chromium:1.61.1
                                              (этот репозиторий)
```

WebDriver Chrome/Firefox — другие образы ([twilio/selenoid](https://hub.docker.com/r/twilio/selenoid)), они здесь не собираются.

## Связанные репозитории

| GitHub | Связь |
|--------|-------|
| [selenoid](https://github.com/qa-guru/selenoid) | Hub — запускает эти образы |
| [selenoid-ui](https://github.com/qa-guru/selenoid-ui) | UI для VNC/Create Session |
| [cm](https://github.com/qa-guru/cm) | `docker pull` при установке |
| **playwright-image** (этот) | Browser nodes |

Конфиг hub: [`config/browsers.json` в qa-guru/selenoid](https://github.com/qa-guru/selenoid/blob/main/config/browsers.json).

---

## Образы

| Docker image | Playwright browser | URL-пример |
|---|---|---|
| `qaguru/playwright-chromium` | Chromium | `/playwright/playwright-chromium/1.61.1` |
| `qaguru/playwright-firefox` | Firefox | `/playwright/playwright-firefox/1.61.1` |
| `qaguru/playwright-webkit` | WebKit | `/playwright/playwright-webkit/1.61.1` |
| `qaguru/playwright-chrome` | Google Chrome | `/playwright/playwright-chrome/1.61.1` |
| `qaguru/playwright-msedge` | Microsoft Edge | `/playwright/playwright-msedge/1.61.1` |

Каждый образ — self-contained node: Xvfb, VNC, `launchServer` через `/opt/playwright/entrypoint.sh`. Hub передаёт env (`ENABLE_VNC`, `ENABLE_VIDEO`, `PW_HEADLESS`, …) и использует `ENTRYPOINT` образа.

---

## Структура репозитория

```
playwright-image/
├── shared/                  # entrypoint, server.cjs, VNC helpers
├── playwright-chromium/
├── playwright-firefox/
├── playwright-webkit/
├── playwright-chrome/
├── playwright-msedge/
└── scripts/
    ├── build.sh
    └── push.sh
```

---

## Pull

```bash
docker pull qaguru/playwright-chromium:1.61.1
docker pull qaguru/playwright-firefox:1.61.1
docker pull qaguru/playwright-webkit:1.61.1
docker pull qaguru/playwright-chrome:1.61.1    # linux/amd64 only
docker pull qaguru/playwright-msedge:1.61.1    # linux/amd64 only
```

| Browser | linux/arm64 | linux/amd64 |
|---|---|---|
| chromium, firefox, webkit | ✅ | ✅ |
| chrome, msedge | ❌ | ✅ |

---

## Сборка

```bash
chmod +x scripts/build.sh scripts/push.sh

# один браузер
./scripts/build.sh chromium 1.61.1

# все браузеры
./scripts/build.sh all 1.61.1
```

## Публикация

```bash
docker login
./scripts/push.sh all 1.61.1
```

Тег: `<playwright-version>` (например `1.61.1`).

---

## browsers.json

```json
{
  "playwright-chromium": {
    "default": "1.61.1",
    "versions": {
      "1.61.1": {
        "image": "qaguru/playwright-chromium:1.61.1",
        "port": "3000",
        "path": "/",
        "protocol": "playwright",
        "playwrightVersion": "1.61.1",
        "user": "pwuser",
        "workDir": "/home/pwuser",
        "shmSize": 2147483648
      }
    }
  }
}
```

WebDriver `chrome` / `firefox` и Playwright `chrome` / `firefox` — разные ключи в каталоге:

- WebDriver: `chrome`, `firefox`
- Playwright: `playwright-chromium`, `playwright-firefox`, `playwright-webkit`, `playwright-chrome`, `playwright-msedge`

---

## Контракт hub ↔ образ

Hub передаёт env (см. `playwright_docker.go` в [qa-guru/selenoid](https://github.com/qa-guru/selenoid)):

| Env | Назначение |
|---|---|
| `ENABLE_VNC` | x11vnc на :5900 |
| `ENABLE_VIDEO` | Xvfb для video-recorder sidecar |
| `SCREEN_RESOLUTION` | разрешение Xvfb |
| `PW_PORT` | порт run-server (обычно 3000) |
| `PW_HEADLESS` | headless для run-server |
| `MANUAL_SESSION` | headed launcher для UI |

Пути в образе:

| Путь | Назначение |
|---|---|
| `/opt/playwright/entrypoint.sh` | старт Xvfb / VNC / server |
| `/opt/playwright/server.cjs` | `browserType.launchServer()` |
| `/opt/playwright/launch-headed-browser.js` | ручные VNC-сессии в UI |
