# WebDriver browser images

Часть репозитория [`browser-image`](../README.md) (`webdriver/`). Playwright-образы — в [`playwright/`](../playwright/).

Selenium WebDriver nodes (`chromedriver`) для Selenoid `/wd/hub`.

## Варианты

| Variant | Docker tag | Dockerfile | Назначение |
|---------|------------|------------|------------|
| **warm** | `qaguru/webdriver-chrome:149` | `Dockerfile.warm` | prod, UI, VNC (`ENABLE_VNC=true`) |
| **min** | `qaguru/webdriver-chrome:149-min` | `Dockerfile.min.scratch` | headless CI, multi-arch |

CfT совпадает с Chromium в `qaguru/playwright-chromium:<pw>-min`. Вход для сборки — **Chrome major** (`148`, `149`).

## Build

```bash
chmod +x scripts/build.sh scripts/push.sh

./scripts/build.sh chrome 149 warm   # -> qaguru/webdriver-chrome:149
./scripts/build.sh chrome 149 min    # -> qaguru/webdriver-chrome:149-min
./scripts/build.sh chrome 149 both   # warm + min
./scripts/build.sh chrome all both   # все мажоры, оба варианта
```

## Publish

```bash
docker login
./scripts/push.sh chrome 149 warm
./scripts/push.sh chrome 149 min
./scripts/push.sh chrome 149 both
```

## Releases

```bash
git tag webdriver/chrome-149 && git push origin webdriver/chrome-149
git tag webdriver/chrome-149-min && git push origin webdriver/chrome-149-min
```

## Run

```bash
# warm + VNC
docker run -d --name chrome-warm \
  -p 4444:4444 -p 5900:5900 \
  -e ENABLE_VNC=true \
  --shm-size=2g \
  qaguru/webdriver-chrome:149

# min (headless CI)
docker run -d --name chrome-min \
  -p 4444:4444 \
  --shm-size=2g \
  qaguru/webdriver-chrome:149-min
```

## browsers.json

```json
{
  "chrome": {
    "default": "149.0",
    "versions": {
      "149.0": {
        "image": "qaguru/webdriver-chrome:149",
        "port": "4444",
        "path": "/",
        "tmpfs": { "/tmp": "size=512m" }
      },
      "149.0-min": {
        "image": "qaguru/webdriver-chrome:149-min",
        "port": "4444",
        "path": "/",
        "tmpfs": { "/tmp": "size=512m" }
      },
      "148.0-min": {
        "image": "qaguru/webdriver-chrome:148-min",
        "port": "4444",
        "path": "/",
        "tmpfs": { "/tmp": "size=512m" }
      }
    }
  }
}
```

## Test connection

```bash
export SELENOID_URL=http://127.0.0.1:4444/wd/hub
./gradlew test --tests 'tests.LoginTests.successfulAuthorizationTest' \
  -Denv=ci -DbrowserVersion=149.0-min
```
