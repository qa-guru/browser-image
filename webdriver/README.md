# WebDriver browser images

<!-- stack-branches-note:start -->
> **Stack pin:** стабильные сборки всего стека — ветки [`selenoid2-1.45-engine26.1-go1.26-react16`](https://github.com/qa-guru/browser-image/tree/selenoid2-1.45-engine26.1-go1.26-react16) (**v2.2.1**, API 1.45 / Engine 26.1.x / Go 1.26.5 / React 16) и [`selenoid2-1.55-engine29.6-go1.26-react18`](https://github.com/qa-guru/browser-image/tree/selenoid2-1.55-engine29.6-go1.26-react18) (**v2.3.0**, API 1.55 / Engine 29.6+ / Go 1.26.5 / React 18). Детали — [`STACK-PIN.md`](../STACK-PIN.md) · [корневой README](../README.md) · [monorepo SSOT](https://github.com/qa-guru/zero-design-system/blob/master/projects/selenoid-home/README.md).
<!-- stack-branches-note:end -->


Часть репозитория [`browser-image`](../README.md) (`webdriver/`). Playwright-образы — в [`playwright/`](../playwright/).

Selenium WebDriver nodes для Selenoid `/wd/hub` (driver на `/`, не Selenium server).

## Браузеры

| Browser | Driver | Warm tag | Min tag | Архитектура |
|---------|--------|----------|---------|-------------|
| Chrome | chromedriver | `qaguru/webdriver-chrome:149` | `:149-min` | amd64 + arm64 |
| Firefox | geckodriver 0.37 | `qaguru/webdriver-firefox:151` | `:151-min` | amd64 + arm64 (ESR) |
| Edge | msedgedriver | `qaguru/webdriver-msedge:145` | `:145-min` | **amd64 only** |

## Варианты

| Variant | Назначение |
|---------|------------|
| **warm** | prod, UI, VNC (`ENABLE_VNC=true`, порт 5900, пароль `selenoid`) |
| **min** | headless CI |

## Build

```bash
chmod +x scripts/build.sh scripts/push.sh

./scripts/build.sh chrome 149 warm
./scripts/build.sh firefox 151 both    # warm + min
./scripts/build.sh msedge 145 min
./scripts/build.sh all all both        # все браузеры и мажоры
```

## Publish

```bash
docker login
./scripts/push.sh firefox 151 both
./scripts/push.sh msedge 145 both
```

## Releases

```bash
git tag webdriver/firefox-151 && git push origin webdriver/firefox-151
git tag webdriver/firefox-151-min && git push origin webdriver/firefox-151-min
git tag webdriver/msedge-145 && git push origin webdriver/msedge-145
git tag webdriver/msedge-145-min && git push origin webdriver/msedge-145-min
```

## Run

```bash
# Firefox warm + VNC
docker run -d --name ff-warm \
  -p 4444:4444 -p 5900:5900 \
  -e ENABLE_VNC=true \
  --shm-size=2g \
  qaguru/webdriver-firefox:151

# Edge min (headless CI)
docker run -d --name edge-min \
  -p 4444:4444 \
  --shm-size=2g \
  qaguru/webdriver-msedge:145-min
```

## browsers.json

```json
{
  "firefox": {
    "default": "151.0",
    "versions": {
      "151.0": {
        "image": "qaguru/webdriver-firefox:151",
        "port": "4444",
        "path": "/",
        "tmpfs": { "/tmp": "size=512m" }
      },
      "151.0-min": {
        "image": "qaguru/webdriver-firefox:151-min",
        "port": "4444",
        "path": "/",
        "tmpfs": { "/tmp": "size=512m" }
      }
    }
  },
  "msedge": {
    "default": "145.0",
    "versions": {
      "145.0": {
        "image": "qaguru/webdriver-msedge:145",
        "port": "4444",
        "path": "/",
        "tmpfs": { "/tmp": "size=512m" }
      }
    }
  }
}
```

Geckodriver: `--allow-hosts localhost 127.0.0.1` (Selenoid шлёт корректный `Host` с портом).  
Edge/Chrome в Docker: wrapper добавляет `--no-sandbox`, `--disable-dev-shm-usage`.

## Test connection

```bash
export SELENOID_URL=http://127.0.0.1:4444/wd/hub
./gradlew test -Denv=ci -Dbrowser=firefox -DbrowserVersion=151.0-min
```
