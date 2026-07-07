# browser-image

Один git-репозиторий [qa-guru/browser-image](https://github.com/qa-guru/browser-image) для Docker-образов браузерных нод Selenoid.

| Папка | Образы | Upstream | Документация |
|-------|--------|----------|--------------|
| [`playwright/`](playwright/) | `qaguru/playwright-*` | `mcr.microsoft.com/playwright` + npm `@playwright/test` | Playwright nodes + `chromium-min` |
| [`webdriver/`](webdriver/) | `qaguru/webdriver-chrome*-min` | Chrome for Testing (Google) | headless `chrome-min` |

**Twilio** (`twilio/selenoid`) — исторический legacy; в `browsers.json`, CI и сборке не используется.

Подробная таблица стека: [selenoid/docs/browser-versions.md](../selenoid/docs/browser-versions.md).

## Быстрый старт

```bash
# Playwright
./playwright/scripts/build.sh chromium 1.61.1
./playwright/scripts/build.sh chromium 1.61.1 min

# WebDriver (chrome-min only)
./webdriver/scripts/build.sh chrome 149 min
```

## Releases

Два независимых release line:

| Стек | Git tag (канон) | Docker tag |
|------|-----------------|------------|
| Playwright | `playwright/1.61.1` | `qaguru/playwright-chromium:1.61.1` |
| WebDriver min | `webdriver/chrome-149-min` | `qaguru/webdriver-chrome:149-min` |

Публикация — `playwright/README.md`, `webdriver/README.md`. CI: `.github/workflows/`.
