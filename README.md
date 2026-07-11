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

> PNG previews update after each orchestrator run on `main` (full stack + per-component crops).

| Link | Description |
|------|-------------|
| [Dashboard](https://qa-guru.github.io/selenoid-tests/reports/latest/dashboard/) | Full pyramid — all hub components |
| [Awesome](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/) | Epic **webdriver-image** + **playwright-image** |
| [selenoid-tests](https://github.com/qa-guru/selenoid-tests) | Orchestrator + merged Allure |

Ethalon: `generators/ethalon/readme/blocks/webdriver-image.md` · `playwright-image.md`

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
| [`video-recorder/`](video-recorder/) | `qaguru/video-recorder` | fork `aerokube/images/selenium/video` | Selenoid `enableVideo` sidecar · deploy-smoke `testVideoRecorder` |

**Twilio** (`twilio/selenoid`) — исторический legacy; в `browsers.json`, CI и сборке не используется.

Подробная таблица стека: [selenoid/docs/browser-versions.md](../selenoid/docs/browser-versions.md).

## Быстрый старт

```bash
# Playwright
./playwright/scripts/build.sh chromium 1.61.1
./playwright/scripts/build.sh chromium 1.61.1 min

# WebDriver (chrome, firefox, msedge)
./webdriver/scripts/build.sh chrome 149 warm
./webdriver/scripts/build.sh firefox 151 both
./webdriver/scripts/build.sh msedge 145 min

# Video recorder (Selenoid sidecar)
./video-recorder/scripts/build.sh
```

## Releases

Канонические git-теги = префикс стека + версия Docker:

| Стек | Git tag | Docker |
|------|---------|--------|
| Playwright | `playwright/1.61.1` | `qaguru/playwright-chromium:1.61.1` |
| Playwright min | `playwright/1.61.1-min` | `qaguru/playwright-chromium:1.61.1-min` |
| WebDriver warm | `webdriver/chrome-149` · `webdriver/firefox-151` · `webdriver/msedge-145` | `qaguru/webdriver-*` |
| WebDriver min | `webdriver/chrome-149-min` · `webdriver/firefox-151-min` · `webdriver/msedge-145-min` | `qaguru/webdriver-*:-min` |
| Video recorder | `video-recorder/1.0.0` | `qaguru/video-recorder:1.0.0` · `:latest` |

Публикация — `playwright/README.md`, `webdriver/README.md`. CI: `.github/workflows/`.
