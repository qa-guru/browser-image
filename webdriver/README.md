# WebDriver browser images

Часть репозитория [`browser-image`](../README.md) (`webdriver/`). Playwright-образы — в [`playwright/`](../playwright/).

Headless `chrome-min` nodes for Selenium WebDriver (chromedriver only).

## Versioning

WebDriver releases are **Chrome-native**:

| Docker tag | CfT | Назначение |
|------------|-----|------------|
| `qaguru/webdriver-chrome:148-min` | `148.0.7778.96` | headless CI, multi-arch |
| `qaguru/webdriver-chrome:149-min` | `149.0.7827.55` | headless CI, multi-arch |

CfT совпадает с Chromium в `qaguru/playwright-chromium:<pw>-min`. Вход для сборки — **Chrome major** (`148`, `149`).

## Build

```bash
chmod +x scripts/build.sh scripts/push.sh

./scripts/build.sh chrome 149 min   # -> qaguru/webdriver-chrome:149-min
./scripts/build.sh chrome 148 min   # -> qaguru/webdriver-chrome:148-min
./scripts/build.sh chrome all min   # обе min-версии (149, 148)
```

`Dockerfile.min.scratch` — headless CI (amd64 = CfT Chrome, arm64 = Debian Chromium).

## Publish

```bash
docker login
./scripts/push.sh chrome 149 min
./scripts/push.sh chrome 148 min
./scripts/push.sh chrome all min
```

## Releases

```bash
git tag webdriver/chrome-149-min && git push origin webdriver/chrome-149-min
```

Legacy tag `chrome-149-min` больше не используется — только `webdriver/chrome-149-min`.

## Run

```bash
docker run -d --name chrome-min \
  -p 4444:4444 \
  --shm-size=2g \
  qaguru/webdriver-chrome:149-min
```

## browsers.json

```json
{
  "chrome": {
    "default": "148.0-min",
    "versions": {
      "148.0-min": {
        "image": "qaguru/webdriver-chrome:148-min",
        "port": "4444",
        "path": "/",
        "tmpfs": { "/tmp": "size=512m" }
      },
      "149.0-min": {
        "image": "qaguru/webdriver-chrome:149-min",
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
  -Denv=ci -DbrowserVersion=148.0-min
```
