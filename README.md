# browser-image


## Automated Tests Dashboard

Live SVG from [selenoid-tests](https://github.com/qa-guru/selenoid-tests) merged Allure (filter `@Component`).

### Stack overview

[![Selenoid stack](https://qa-guru.github.io/selenoid-tests/readme/badge.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/dashboard/)

[![Stack stats](https://qa-guru.github.io/selenoid-tests/readme/stats.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/dashboard/)

<a href="https://qa-guru.github.io/selenoid-tests/reports/latest/dashboard/">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://qa-guru.github.io/selenoid-tests/readme/dashboard-preview-dark.png">
    <img
      src="https://qa-guru.github.io/selenoid-tests/readme/dashboard-preview.png"
      alt="Allure 3 dashboard — full Selenoid stack (all components)"
      width="800"
    />
  </picture>
</a>

### WebDriver browser nodes

[![WebDriver nodes](https://qa-guru.github.io/selenoid-tests/readme/badge-webdriver-image.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

[![WebDriver stats](https://qa-guru.github.io/selenoid-tests/readme/stats-webdriver-image.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

[![WebDriver metrics](https://qa-guru.github.io/selenoid-tests/readme/metrics-panel-webdriver-image.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

<a href="https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://qa-guru.github.io/selenoid-tests/readme/dashboard-preview-webdriver-image-dark.png">
    <img
      src="https://qa-guru.github.io/selenoid-tests/readme/dashboard-preview-webdriver-image.png"
      alt="Allure 3 dashboard — WebDriver nodes only"
      width="800"
    />
  </picture>
</a>

### Playwright browser nodes

[![Playwright nodes](https://qa-guru.github.io/selenoid-tests/readme/badge-playwright-image.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

[![Playwright stats](https://qa-guru.github.io/selenoid-tests/readme/stats-playwright-image.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

[![Playwright metrics](https://qa-guru.github.io/selenoid-tests/readme/metrics-panel-playwright-image.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

<a href="https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://qa-guru.github.io/selenoid-tests/readme/dashboard-preview-playwright-image-dark.png">
    <img
      src="https://qa-guru.github.io/selenoid-tests/readme/dashboard-preview-playwright-image.png"
      alt="Allure 3 dashboard — Playwright nodes only"
      width="800"
    />
  </picture>
</a>

### Video recorder sidecar

[![Video recorder](https://qa-guru.github.io/selenoid-tests/readme/badge-video-recorder.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

[![Video recorder stats](https://qa-guru.github.io/selenoid-tests/readme/stats-video-recorder.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

[![Video recorder metrics](https://qa-guru.github.io/selenoid-tests/readme/metrics-panel-video-recorder.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

<a href="https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://qa-guru.github.io/selenoid-tests/readme/dashboard-preview-video-recorder-dark.png">
    <img
      src="https://qa-guru.github.io/selenoid-tests/readme/dashboard-preview-video-recorder.png"
      alt="Allure 3 dashboard — video-recorder sidecar only"
      width="800"
    />
  </picture>
</a>

> PNG previews update after each orchestrator run on `main` (full stack + per-component crops).

| Link | Description |
|------|-------------|
| [Dashboard](https://qa-guru.github.io/selenoid-tests/reports/latest/dashboard/) | Full pyramid — all hub components |
| [Awesome](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/) | Epic **webdriver-image** + **playwright-image** + **video-recorder** |
| [selenoid-tests](https://github.com/qa-guru/selenoid-tests) | Orchestrator + merged Allure |

Ethalon: `generators/ethalon/readme/blocks/webdriver-image.md` · `playwright-image.md` · `video-recorder.md`

Один git-репозиторий [qa-guru/browser-image](https://github.com/qa-guru/browser-image) для Docker-образов браузерных нод Selenoid.

## Экосистема qa-guru Selenoid

| Ресурс | Ссылка | Роль |
|--------|--------|------|
| selenoid | [github.com/qa-guru/selenoid](https://github.com/qa-guru/selenoid) | Hub |
| selenoid-ui | [github.com/qa-guru/selenoid-ui](https://github.com/qa-guru/selenoid-ui) | Web UI |
| cm | [github.com/qa-guru/cm](https://github.com/qa-guru/cm) | Установщик |
| **browser-image** (этот) | [github.com/qa-guru/browser-image](https://github.com/qa-guru/browser-image) | Docker browser nodes |
| selenoid-tests | [github.com/qa-guru/selenoid-tests](https://github.com/qa-guru/selenoid-tests) | E2e/integration ethalon |
| Docker Hub | [hub.docker.com/u/qaguru](https://hub.docker.com/u/qaguru) | Образы `qaguru/*` |

| Папка | Образы | Upstream | Документация |
|-------|--------|----------|--------------|
| [`playwright/`](playwright/) | `qaguru/playwright-*` | `mcr.microsoft.com/playwright` + npm `@playwright/test` | Playwright nodes + `chromium-min` |
| [`webdriver/`](webdriver/) | `qaguru/webdriver-chrome*` · `webdriver-firefox*` · `webdriver-msedge*` | CfT / Mozilla / Microsoft | warm (VNC) + min |
| [`video-recorder/`](video-recorder/) | `qaguru/video-recorder` | fork `aerokube/images/selenium/video` | Selenoid `enableVideo` sidecar · deploy-smoke `source_variant=video-recorder` |

**Twilio** (`twilio/selenoid`) — исторический legacy; в `browsers.json`, CI и сборке не используется.

Подробная таблица стека: [selenoid/docs/browser-versions.md](../selenoid/docs/browser-versions.md).

## Быстрый старт

```bash
# Playwright
./playwright/scripts/build.sh chromium 1.62.1
./playwright/scripts/build.sh chromium 1.62.1 min

# WebDriver (chrome, firefox, msedge)
./webdriver/scripts/build.sh chrome 152 warm
./webdriver/scripts/build.sh firefox 154 both
./webdriver/scripts/build.sh msedge 151 min

# Video recorder (Selenoid sidecar)
./video-recorder/scripts/build.sh
```

## Releases

Канонические git-теги = префикс стека + версия Docker:

| Стек | Git tag | Docker |
|------|---------|--------|
| Playwright | `playwright/1.62.1` | `qaguru/playwright-chromium:1.62.1` |
| Playwright min | `playwright/1.62.1-min` | `qaguru/playwright-chromium:1.62.1-min` |
| WebDriver warm | `webdriver/chrome-152` · `webdriver/firefox-154` · `webdriver/msedge-151` | `qaguru/webdriver-*` |
| WebDriver min | `webdriver/chrome-152-min` · `webdriver/firefox-154-min` · `webdriver/msedge-151-min` | `qaguru/webdriver-*:-min` |
| Video recorder | `video-recorder/1.0.0` | `qaguru/video-recorder:1.0.0` · `:latest` |

Публикация — `playwright/README.md`, `webdriver/README.md`. CI: `.github/workflows/`.

## Watch → prod (без кнопки)

Пины — [`pins.json`](pins.json). Cron `watch.yml` каждые 15 мин (и `workflow_dispatch`):

1. Резолв latest **stable** (CfT last-known-good, Firefox product-details + FTP, Edge apt amd64, npm `@playwright/test` + MCR `vX-noble`).
2. No-op, если окно default+regression уже совпадает.
3. Commit `pins.json` → git-теги **по одному** (`webdriver/chrome-N`, `…-min`, `playwright/x.y.z`) → Docker Hub 200. Тег-publish **не** диспатчит прод (иначе N деплоев до каталога).
4. Мажор: SSOT-каталог в nested-репах, **последним** `deploy/browsers-production.json` на [selenoid.qa.guru](https://github.com/qa-guru/selenoid.qa.guru). Box1 копирует файл, `docker pull`, **SIGHUP хабу** (сессии живые). Hub/UI процессы не гасятся.
5. Патч того же мажора: `pull-prod` (`pull_browsers=always`, без `version` / `ui_version`) — тот же browsers-only путь.

Локально: `python3 scripts/watch_upstream.py self-check && python3 scripts/watch_upstream.py resolve`.

Секрет: `SELENOID_TESTS_DISPATCH_TOKEN` — PAT `contents:write` на `browser-image` + catalog-репы и `repo` на `selenoid.qa.guru` (теги с `GITHUB_TOKEN` не стартуют Actions).
