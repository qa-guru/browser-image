# WebDriver browser images

Часть репозитория [`browser-image`](../README.md) (`webdriver/`). Playwright-образы — в [`playwright/`](../playwright/).

Warm WebDriver browser nodes for [warm-pool-orchestrator](../warm-pool-orchestrator/README.md).

Long-lived Chrome slots with HTTP warm API (`/warm/goto`, `/warm/reset`, `/warm/video/*`) and always-on chromedriver.

## Versioning

WebDriver releases are **Chrome-native**, not Playwright semver:

| Docker tag | CfT | Назначение |
|------------|-----|------------|
| `qaguru/webdriver-chrome:148` | `148.0.7778.96` | warm pool (VNC + warm API) |
| `qaguru/webdriver-chrome:149` | `149.0.7827.55` | warm pool |
| `qaguru/webdriver-chrome:148-min` | `148.0.7778.96` | headless CI, multi-arch |
| `qaguru/webdriver-chrome:149-min` | `149.0.7827.55` | headless CI, multi-arch |

CfT совпадает с Chromium в `qaguru/playwright-chromium:<pw>-min`, но **вход для сборки — Chrome major** (`148`, `149`), не `1.60.0` / `1.61.1`.

## Images

| Image | Base | Ports | Use case |
|-------|------|-------|----------|
| `qaguru/webdriver-chrome:148` | Chrome 148 + warm API layer | `4444` WebDriver, `8080` warm API, `5900` VNC | warm pool / Selenium |
| `qaguru/webdriver-chrome:149-min` | CfT `149.0.7827.55` on `debian:bookworm` (amd64) / Chromium (arm64) | `4444` WebDriver | headless CI, multi-arch |

`chrome-min` — только chromedriver, без VNC / warm API / Xvfb.

## Build

```bash
chmod +x scripts/build.sh scripts/push.sh

# warm pool (VNC + warm API)
./scripts/build.sh chrome 148

# chrome-min (headless CI) — Chrome major, не PW semver
./scripts/build.sh chrome 149 min   # -> qaguru/webdriver-chrome:149-min
./scripts/build.sh chrome 148 min   # -> qaguru/webdriver-chrome:148-min
./scripts/build.sh chrome all min   # обе min-версии (149, 148)

# полный CfT-тег тоже принимается
./scripts/build.sh chrome 149.0.7827.55 min
```

Warm-сборка копирует `warm-api` из `warm-pool-orchestrator/warm-api` (monorepo) или из закоммиченного `vendor/warm-api/` (CI / standalone clone).

`Dockerfile.scratch` — канон для warm (Chrome for Testing + Ubuntu Noble + VNC/warm API).  
`Dockerfile.min.scratch` — канон для min (headless CI, multi-arch: amd64 = CfT Chrome, arm64 = Debian Chromium).

## Publish

```bash
docker login
./scripts/push.sh chrome 148              # warm
./scripts/push.sh chrome 149 min          # 149-min
./scripts/push.sh chrome 148 min          # 148-min
./scripts/push.sh all 148                 # warm + обе min
```

## Releases

Git tag → Docker Hub + GitHub Release (workflow `publish-webdriver`):

```bash
# warm + текущие min-образы
git tag webdriver/chrome-148 && git push origin webdriver/chrome-148

# только min
git tag webdriver/chrome-149-min && git push origin webdriver/chrome-149-min
```

Legacy tags `chrome-148` / `chrome-149-min` по-прежнему триггерят CI.  
Префикс `webdriver/` — канон для release line, отдельно от `playwright/1.61.1`.

## Run (single slot)

```bash
docker run -d --name warm-chrome-1 \
  --network warm-pool \
  -p 4444:4444 \
  -p 8080:8080 \
  -e WARM_SLOT_ID=pool-chrome-1 \
  -e WARM_SESSION_ID=pool-chrome-1 \
  -v "$(pwd)/video:/data/video" \
  qaguru/webdriver-chrome:148
```

## Run (chrome-min, headless)

```bash
docker run -d --name chrome-min \
  -p 4444:4444 \
  --shm-size=2g \
  qaguru/webdriver-chrome:149-min
```

## Warm API

Same contract as Playwright warm slots — see [warm-pool-orchestrator/README.md](../warm-pool-orchestrator/README.md#warm-api-contract).

```bash
curl -sf http://127.0.0.1:8080/warm/status | jq .
curl -sf -X POST http://127.0.0.1:8080/warm/goto \
  -H 'Content-Type: application/json' \
  -d '{"url":"https://example.com/login.html"}'
curl -sf -X POST http://127.0.0.1:8080/warm/video/start \
  -H 'Content-Type: application/json' \
  -d '{"sessionId":"pool-chrome-1"}'
curl -sf -X POST http://127.0.0.1:8080/warm/video/stop
```

Video files: `{sessionId}-{timestamp}.mp4` in `/data/video` (mount from host).

## browsers.json

```json
{
  "chrome": {
    "default": "148.0",
    "versions": {
      "148.0": {
        "image": "qaguru/webdriver-chrome:148",
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
  -Denv=ci -DbrowserVersion=148.0
```

For attach to the slot's pre-created session (fastest path), use orchestrator reserve + `-Dwarm.attach=true` (see orchestrator README).
