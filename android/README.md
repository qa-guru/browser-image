# android — `qaguru/android`

Учебный Selenoid-нод: **Appium 3.5 + UiAutomator2 + AVD API 36 (Android 16)**, VNC `:5900`, video через sidecar `qaguru/video-recorder`. Это **не** ферма устройств и **не** iOS.

| | |
|---|---|
| Node | **24** (канон стека) |
| Appium | **3.5.2** |
| UiAutomator2 | **8.1.0** |
| AVD | API 36 · `google_apis` · **x86_64** · skin `1080x1920` |
| Xvfb / VNC canvas | **`1080x1920x24`** (portrait, matches phone skin; not browser landscape) |

| Docker | Назначение |
|--------|------------|
| `qaguru/android:16` | Android 16 / API 36 · Linux+KVM |

Основа паттерна — [aerokube/images selenium/android](https://github.com/aerokube/images/tree/master/selenium/android) (Apache 2.0). **Без** budtmo / sponsor Pro blobs.

## Mac vs Linux+KVM

| Хост | Сборка `linux/amd64` | Smoke-сессия |
|------|----------------------|--------------|
| **Mac** | да | **нет** (нет `/dev/kvm`; Mac-runtime — later) |
| **Linux + KVM** | да | да — privileged, без `-disable-privileged` |

## Build

```bash
chmod +x scripts/build.sh scripts/push.sh entrypoint.sh
./scripts/build.sh        # → qaguru/android:16
./scripts/build.sh 16
```

Платформа всегда `linux/amd64`.

## browsers.json (SSOT)

`dev/browsers.json` → `android` / `16.0` → `qaguru/android:16`. После правок: `dev/scripts/sync-cm-browsers.sh`.

## Smoke (Linux+KVM)

```bash
curl -s -X POST http://127.0.0.1:4444/wd/hub/session \
  -H 'Content-Type: application/json' \
  -d '{
    "capabilities": {
      "alwaysMatch": {
        "browserName": "android",
        "browserVersion": "16.0",
        "selenoid:options": { "enableVNC": true }
      }
    }
  }'
```

Video: `enableVideo: true` + `qaguru/video-recorder`. VNC пароль: `selenoid`.

## Вне scope / deferred

- Mac runtime (arm64 / soft accel)
- iOS / XCUITest
- budtmo / Pro
- device farm
- Chrome Mobile / chromedriver в этом образе
