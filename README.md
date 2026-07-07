# browser-image

Один git-репозиторий [qa-guru/browser-image](https://github.com/qa-guru/browser-image) для Docker-образов браузерных нод Selenoid.

| Папка | Образы | Upstream | Документация |
|-------|--------|----------|--------------|
| [`playwright/`](playwright/) | `qaguru/playwright-*` | `mcr.microsoft.com/playwright` + npm `@playwright/test` | Playwright nodes + `chromium-min` |
| [`webdriver/`](webdriver/) | `qaguru/webdriver-chrome*` | Chrome for Testing (Google) | Warm WebDriver + `chrome-min` |

**Twilio** (`twilio/selenoid`) — только исторический legacy для cold WebDriver-образов; в `browsers.json`, CI и сборке не используется. Playwright всегда Microsoft base + qaguru wrapper (мы не форкаем upstream Playwright).

Подробная таблица стека: [selenoid/docs/browser-versions.md](../selenoid/docs/browser-versions.md) · полный каталог версий по браузерам и источникам (Microsoft / aerokube / Twilio / qaguru): [driver-versions-catalog.md](../selenoid/docs/driver-versions-catalog.md).

## Быстрый старт

```bash
# Playwright
./playwright/scripts/build.sh chromium 1.61.1
./playwright/scripts/build.sh chromium 1.61.1 min

# WebDriver
./webdriver/scripts/build.sh chrome 148
./webdriver/scripts/build.sh chrome 149 min
```

## Releases

Два независимых release line в одном репозитории:

| Стек | Git tag (канон) | Legacy tag | Docker tag | GitHub Release title |
|------|-----------------|------------|------------|----------------------|
| Playwright | `playwright/1.61.1` | `1.61.1` | `qaguru/playwright-chromium:1.61.1` | Playwright 1.61.1 |
| WebDriver warm | `webdriver/chrome-148` | `chrome-148` | `qaguru/webdriver-chrome:148` | WebDriver chrome-148 |
| WebDriver min | `webdriver/chrome-149-min` | `chrome-149-min` | `qaguru/webdriver-chrome:149-min` | WebDriver chrome-149-min |

Версии WebDriver — **Chrome major** (148, 149), не semver Playwright. CfT в `webdriver-min` совпадает с Chromium в `playwright-chromium:<pw>-min`, но вход для сборки — chrome major.

Публикация — см. `playwright/README.md` и `webdriver/README.md`. CI: `.github/workflows/`.
