# browser-image

Один git-репозиторий [qa-guru/browser-image](https://github.com/qa-guru/browser-image) для Docker-образов браузерных нод Selenoid.

| Папка | Образы | Upstream | Документация |
|-------|--------|----------|--------------|
| [`playwright/`](playwright/) | `qaguru/playwright-*` | `mcr.microsoft.com/playwright` + npm `@playwright/test` | Playwright nodes + `chromium-min` |
| [`webdriver/`](webdriver/) | `qaguru/webdriver-chrome*` · `webdriver-firefox*` · `webdriver-msedge*` | CfT / Mozilla / Microsoft | warm (VNC) + min |

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
```

## Releases

Канонические git-теги = префикс стека + версия Docker:

| Стек | Git tag | Docker |
|------|---------|--------|
| Playwright | `playwright/1.61.1` | `qaguru/playwright-chromium:1.61.1` |
| Playwright min | `playwright/1.61.1-min` | `qaguru/playwright-chromium:1.61.1-min` |
| WebDriver warm | `webdriver/chrome-149` · `webdriver/firefox-151` · `webdriver/msedge-145` | `qaguru/webdriver-*` |
| WebDriver min | `webdriver/chrome-149-min` · `webdriver/firefox-151-min` · `webdriver/msedge-145-min` | `qaguru/webdriver-*:-min` |

Публикация — `playwright/README.md`, `webdriver/README.md`. CI: `.github/workflows/`.
