# browser-image

<!-- stack-branches-note:start -->
> ## Стабильные билды — две ветки
>
> Стабильные версии стека зафиксированы в **двух долгоживущих ветках** (а не в `main`):
>
> | Ветка | Стабильный билд | Docker API | Engine | Go |
> |-------|-----------------|------------|--------|-----|
> | `selenoid2-1.45-engine26.1-go1.23` | **v2.2.1** — прежний prod ([selenoid.autotests.cloud](https://selenoid.autotests.cloud)) | 1.45 | 26.1.x | 1.26.5 |
> | `selenoid2-1.55-engine29-go1.26` | **v2.3.0** — актуальный, до нового UI (Selenoid 3) | 1.55 | 29.x | 1.26.5 |
>
> **Зачем две ветки:** каждая держит воспроизводимый набор версий. Обновление Docker Engine 26.1.x → 29.x (API 1.45 → 1.55) вынесено в отдельную ветку, чтобы прежний prod-стек собирался в любой момент. `main` — активная разработка, может меняться. Точные версии — в `STACK-PIN.md` в корне ветки.
>
> _Вы на ветке `selenoid2-1.45-engine26.1-go1.23`._
<!-- stack-branches-note:end -->


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
