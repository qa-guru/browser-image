# Playwright browser images

Часть репозитория [`browser-image`](../README.md) (`playwright/`). WebDriver-образы — в [`webdriver/`](../webdriver/).

Docker-образы browser nodes для [qa-guru/selenoid](https://github.com/qa-guru/selenoid). Hub поднимает их по запросу и проксирует Playwright WebSocket на `/playwright/{browser}/{version}`.

[![Publish](https://github.com/qa-guru/browser-image/workflows/publish/badge.svg)](https://github.com/qa-guru/browser-image/actions?query=workflow%3Apublish)
[![Release](https://img.shields.io/github/release/qa-guru/browser-image.svg)](https://github.com/qa-guru/browser-image/releases/latest)

[![Docker Pulls Chromium](https://img.shields.io/docker/pulls/qaguru/playwright-chromium.svg?label=chromium)](https://hub.docker.com/r/qaguru/playwright-chromium)
[![Docker Pulls Firefox](https://img.shields.io/docker/pulls/qaguru/playwright-firefox.svg?label=firefox)](https://hub.docker.com/r/qaguru/playwright-firefox)
[![Docker Pulls WebKit](https://img.shields.io/docker/pulls/qaguru/playwright-webkit.svg?label=webkit)](https://hub.docker.com/r/qaguru/playwright-webkit)
[![Docker Pulls Chrome](https://img.shields.io/docker/pulls/qaguru/playwright-chrome.svg?label=chrome)](https://hub.docker.com/r/qaguru/playwright-chrome)
[![Docker Pulls Edge](https://img.shields.io/docker/pulls/qaguru/playwright-msedge.svg?label=msedge)](https://hub.docker.com/r/qaguru/playwright-msedge)

| | |
|---|---|
| **GitHub** | [qa-guru/browser-image](https://github.com/qa-guru/browser-image) |

| **Docker Hub** | [`qaguru/playwright-chromium`](https://hub.docker.com/r/qaguru/playwright-chromium), [`playwright-firefox`](https://hub.docker.com/r/qaguru/playwright-firefox), [`playwright-webkit`](https://hub.docker.com/r/qaguru/playwright-webkit), [`playwright-chrome`](https://hub.docker.com/r/qaguru/playwright-chrome), [`playwright-msedge`](https://hub.docker.com/r/qaguru/playwright-msedge) |

## Automated Tests Dashboard

[![Playwright nodes](https://qa-guru.github.io/selenoid-tests/readme/badge-playwright-image.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

[![Playwright stats](https://qa-guru.github.io/selenoid-tests/readme/stats-playwright-image.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

[![Playwright metrics](https://qa-guru.github.io/selenoid-tests/readme/metrics-panel-playwright-image.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

<a href="https://qa-guru.github.io/selenoid-tests/reports/latest/dashboard/">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://qa-guru.github.io/selenoid-tests/readme/dashboard-preview-dark.png">
    <img
      src="https://qa-guru.github.io/selenoid-tests/readme/dashboard-preview.png"
      alt="Allure 3 dashboard — pyramid, stability, success distribution"
      width="800"
    />
  </picture>
</a>
> Dashboard PNG updates after each orchestrator run on `main` (Playwright screenshot of Allure 3 dashboard).

| Link | Description |
|------|-------------|
| [Awesome epic playwright-image](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/) | Chromium / Firefox / WebKit node tests |
| [Dashboard](https://qa-guru.github.io/selenoid-tests/reports/latest/dashboard/) | Full pyramid |
| [selenoid-tests](https://github.com/qa-guru/selenoid-tests) | Orchestrator + merged Allure |


## Роль в экосистеме

Это **не hub** — отдельные контейнеры с Playwright `launchServer`, VNC и Xvfb. Hub [qa-guru/selenoid](https://github.com/qa-guru/selenoid) читает `browsers.json`, стартует нужный образ и проксирует WebSocket клиента.

```
Playwright test  ──►  selenoid hub  ──►  qaguru/playwright-chromium:1.60.0
                                              (этот репозиторий)
```

WebDriver Chrome — [`webdriver/`](../webdriver/) (`qaguru/webdriver-chrome*-min`). Firefox и Edge в Selenium-стеке не публикуются — используйте `playwright-firefox` / `playwright-msedge`.

## Связанные репозитории

| GitHub | Связь |
|--------|-------|
| [selenoid](https://github.com/qa-guru/selenoid) | Hub — запускает эти образы |
| [selenoid-ui](https://github.com/qa-guru/selenoid-ui) | UI для VNC/Create Session |
| [cm](https://github.com/qa-guru/cm) | `docker pull` при установке |
| **browser-image** (`playwright/`) | Playwright browser nodes |

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

## Сравнение с Selenium-образами (WebDriver)

В hub [два независимых стека](https://github.com/qa-guru/selenoid/blob/main/docs/browser-versions.md). Поле `version` в `browsers.json` для них означает разное:

| | Playwright (`qaguru/playwright-*`) | WebDriver (`qaguru/webdriver-chrome`) |
|---|---|---|
| **Протокол** | WebSocket `/playwright/...` | HTTP `POST /wd/hub/session` |
| **Что означает версия** | npm `@playwright/test` (`1.60.0`) | мажор браузера (`148.0` → Chrome 148.x) |
| **Клиент** | Playwright / `@playwright/test` | Selenium WebDriver |
| **Образы** | `playwright/` в этом репозитории | `webdriver/` в этом репозитории |

### Движки при версиях по умолчанию

Актуально для [`config/browsers.json`](https://github.com/qa-guru/selenoid/blob/main/config/browsers.json) (июль 2026).

| Браузер | Playwright в hub | Движок в контейнере | WebDriver в hub | Docker-тег qaguru |
|---|---|---|---|---|
| Chromium | `playwright-chromium` **1.60.0** | Chromium **148** | `chrome` **148.0** | `qaguru/webdriver-chrome:148` |
| Google Chrome | `playwright-chrome` **1.60.0** | stable channel | — | — |
| Firefox | `playwright-firefox` **1.60.0** | Firefox **150** | — | — |
| Microsoft Edge | `playwright-msedge` **1.60.0** | stable channel | — | — |
| WebKit | `playwright-webkit` **1.60.0** | WebKit **26.4** | — | — |

> Стеки **нельзя** подменять: `chrome:148.0` ≠ `playwright-chromium:1.60.0`.

### Матрица версий в `browsers.json`

| Имя в hub | Default | Версии в конфиге | Docker-образ |
|---|---|---|---|
| `playwright-chromium` | `1.60.0` | 1.60.0, 1.60.0-min | `qaguru/playwright-chromium:<версия>` |
| `playwright-firefox` | `1.60.0` | 1.60.0 | `qaguru/playwright-firefox:<версия>` |
| `playwright-webkit` | `1.60.0` | 1.60.0 | `qaguru/playwright-webkit:<версия>` |
| `playwright-chrome` | `1.60.0` | 1.60.0 | `qaguru/playwright-chrome:<версия>` |
| `playwright-msedge` | `1.60.0` | 1.60.0 | `qaguru/playwright-msedge:<версия>` |
| `chrome` | `148.0` | 148.0, 148.0-min | `qaguru/webdriver-chrome:148`, `qaguru/webdriver-chrome:148-min` |

### Движки внутри Playwright-образов

Данные из [официального `browsers.json` Playwright](https://github.com/microsoft/playwright/blob/main/packages/playwright-core/browsers.json).

| Playwright | Chromium | Firefox | WebKit | WebDriver Chrome | WebDriver Firefox |
|---|---|---|---|---|---|
| **1.61.1** *(default)* | 149.0.7827.55 | 151.0 | 26.5 | 148.0 | 150.0 |
| 1.61.0 | 149.0.7827.55 | 151.0 | 26.5 | — | — |
| 1.60.0 | 148.0.7778.96 | 150.0.2 | 26.4 | 148.0 | — |

Версия npm-клиента **должна совпадать** с `playwrightVersion` и версией в URL (`/playwright/playwright-chromium/1.61.1` → `@playwright/test@1.61.1`).

Полная матрица совместимости, правила клиента и команды `docker pull` — в [browser-versions.md](https://github.com/qa-guru/selenoid/blob/main/docs/browser-versions.md) (qa-guru/selenoid).

---

## Сравнение с официальным образом Microsoft

Образы `qaguru/playwright-*` **наследуются** от [`mcr.microsoft.com/playwright`](https://playwright.dev/docs/docker) и добавляют слой для Selenoid hub. Движки браузеров и системные зависимости — те же, что в upstream.

| | Microsoft `mcr.microsoft.com/playwright` | `qaguru/playwright-*` (этот репозиторий) |
|---|---|---|
| **Назначение** | CI, разработка, ручной `run-server` | Browser node для [qa-guru/selenoid](https://github.com/qa-guru/selenoid) |
| **Базовый слой** | Ubuntu Noble + браузеры Playwright | `FROM mcr.microsoft.com/playwright:v<версия>-noble` |
| **Образов на версию** | **1** — все браузеры внутри | **5** — отдельный образ на браузер |
| **Playwright npm** | Не включён (ставится отдельно) | `playwright-core@<версия>` в образе |
| **`launchServer`** | Вручную: `npx playwright run-server --port 3000 --host 0.0.0.0` | Автоматически: `/opt/playwright/server.cjs` в `ENTRYPOINT` |
| **Подключение клиента** | Прямой WebSocket к контейнеру (`ws://host:3000/`) | Через hub: `ws://selenoid:4444/playwright/playwright-chromium/1.61.1?enableVNC=true&enableVideo=true` |
| **VNC / headed UI** | noVNC только через [devcontainer feature](https://playwright.dev/docs/docker#connecting-using-novnc-and-github-codespaces) | Xvfb + x11vnc на **:5900** (Selenoid UI, пароль `selenoid`) |
| **Видеозапись** | Нет | `ENABLE_VIDEO` + sidecar `qaguru/video-recorder` |
| **Healthcheck** | Нет | HTTP probe на `:3000` |
| **PID 1 / init** | Рекомендуется `--init` при `docker run` | `dumb-init` в `ENTRYPOINT` |
| **Пользователь** | `root` (по умолчанию) или `pwuser` | `pwuser` |
| **Docker-тег** | `v1.61.1-noble` | `1.61.1` |
| **Реестр** | [Microsoft Artifact Registry](https://mcr.microsoft.com/artifact/mar/playwright/about) | [Docker Hub `qaguru/playwright-*`](https://hub.docker.com/u/qaguru) |

### Браузеры в образе

| Браузер | Microsoft (`v1.61.1-noble`) | `qaguru/playwright-*` |
|---|---|---|
| Chromium | ✅ bundled | `playwright-chromium` |
| Firefox | ✅ bundled | `playwright-firefox` |
| WebKit | ✅ bundled | `playwright-webkit` |
| Google Chrome (stable) | ❌ | `playwright-chrome` (`npx playwright install chrome`) |
| Microsoft Edge (stable) | ❌ | `playwright-msedge` (`npx playwright install msedge`) |

В upstream-образе все три движка в **одном** контейнере; `run-server` отдаёт тот браузер, к которому подключается клиент. Здесь — **отдельный контейнер на браузер**, чтобы hub мог масштабировать и выбирать образ по имени в `browsers.json`.

### Версии и движки

Тег Playwright ↔ движки браузеров **совпадают** с Microsoft-образом той же версии (общий `browsers.json` Playwright). Пример для **1.61.1**:

| | Microsoft | `qaguru/playwright-chromium:1.61.1` |
|---|---|---|
| Базовый образ | — | `mcr.microsoft.com/playwright:v1.61.1-noble` |
| Chromium | 149.0.7827.55 | 149.0.7827.55 |
| Firefox | 151.0 | 151.0 (в `playwright-firefox`) |
| WebKit | 26.5 | 26.5 (в `playwright-webkit`) |

> Официальный образ Microsoft предназначен для **тестов и разработки** ([документация](https://playwright.dev/docs/docker)); для untrusted-сайтов рекомендуют отдельного пользователя и seccomp. Образы `qaguru/playwright-*` рассчитаны на **доверенные e2e-тесты** в инфраструктуре Selenoid.

### Эквивалент `run-server` вручную

Официальный способ remote connect:

```bash
docker run -p 3000:3000 --rm --init --user pwuser \
  mcr.microsoft.com/playwright:v1.61.1-noble \
  /bin/sh -c "npx -y playwright@1.61.1 run-server --port 3000 --host 0.0.0.0"
```

В Selenoid hub делает то же самое за вас: стартует `qaguru/playwright-chromium:1.61.1`, проксирует WebSocket, при необходимости поднимает VNC и video-recorder.

---

## Структура репозитория

```
browser-image/
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

# chromium-only min (headless CI, без VNC/warm)
./scripts/build.sh chromium 1.61.1 min

# все браузеры
./scripts/build.sh all 1.61.1
```

Тег min: `qaguru/playwright-chromium:<version>-min`.  
Сборка min: `Dockerfile.min.scratch` (chromium-only с нуля на `ubuntu:noble`, ~1.6 GB).  
`Dockerfile.min` — запасной вариант на базе `mcr.microsoft.com/playwright` (для локальной сборки, если scratch не нужен).

## Публикация

```bash
docker login
./scripts/push.sh all 1.61.1          # все браузеры + chromium-min
./scripts/push.sh chromium 1.61.1 min # только min
```

Теги: `<playwright-version>` (например `1.61.1`) и `1.61.1-min` для headless CI chromium.  
CI (`publish.yml`) публикует `-min` автоматически вместе с остальными образами.

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
