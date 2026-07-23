# android — `qaguru/android`

Учебный Selenoid-нод: **Appium 3.5 + UiAutomator2 + AVD API 36 (Android 16)**, VNC `:5900`, video через sidecar `qaguru/video-recorder`. Это **не** ферма устройств и **не** iOS.

| | |
|---|---|
| Node | **24** (канон стека) |
| Appium | **3.5.2** |
| UiAutomator2 | **8.1.0** |
| AVD | API 36 · `google_apis` · **x86_64** · skin `1080x1920` |
| Xvfb / VNC canvas | **`2100x2100x24`** (square: skin + Qt title/toolbar margin; portrait + landscape) |

| Docker | Назначение |
|--------|------------|
| `qaguru/android:11` … `:15` | Android 11–15 / API 30–35 · Linux+KVM |
| `qaguru/android:16` | Android 16 / API 36 · Linux+KVM |

Тег образа = major (`11.0` в browsers.json → `:11`). Сборка всех 11–15: `./scripts/build-all.sh` (Linux+KVM).

Основа паттерна — [aerokube/images selenium/android](https://github.com/aerokube/images/tree/master/selenium/android) (Apache 2.0). **Без** budtmo / sponsor Pro blobs.

## Mac vs Linux+KVM

| Хост | Сборка `linux/amd64` | Smoke-сессия |
|------|----------------------|--------------|
| **Mac** | да | **нет** (нет `/dev/kvm`; Mac-runtime — later) |
| **Linux + KVM** | да | да — privileged, без `-disable-privileged` |

## Build

```bash
chmod +x scripts/*.sh entrypoint.sh
./scripts/build.sh 16
```

Платформа всегда `linux/amd64`.

- **Linux + KVM:** `build.sh` вызывает `scripts/prepare-image.sh` и создаёт production `qaguru/android:16` с подготовленным userdata.
- **Mac / хост без KVM:** собирается только `qaguru/android:16-base` для проверки Dockerfile. Production-тег без Linux prepare flow не создаётся.

Prepare flow воспроизводим: первый boot, Android settings, установка точных helper APK из UiAutomator2 8.1.0, один priming-запуск instrumentation, штатный shutdown, копирование userdata в final Docker stage. `docker commit` не используется. `prepared/` — локальный build artifact, не git source.

```bash
# Только Linux + /dev/kvm:
./scripts/prepare-image.sh 16
./scripts/push.sh 16
```

Final image содержит `/opt/qaguru/prepared-avd.env` с версиями и SHA-256 helper APK. Только при наличии marker и фактических packages entrypoint включает:

- `appium:skipServerInstallation=true`;
- `appium:skipDeviceInitialization=true`;
- `appium:skipUnlock=true` после собственного unlock;
- `appium:skipLogcatCapture=true`.

Snapshot policy — явный `-no-snapshot`: userdata подготовлен, но каждый контейнер выполняет обычный disposable boot. Quick Boot / restore относится к deferred warm pool.

## browsers.json (SSOT)

`dev/browsers.json` → `android` **4.4 + 10.0–16.0** (8 версий), default **10.0** (`selenoid/android:10.0`); **11.0–16.0** → `qaguru/android:11`…`:16`. Legacy aerokube: только **`4.4`**. Prod: `dev/browsers-production.json`. После правок: `dev/scripts/sync-cm-browsers.sh`.

Env по умолчанию: `SCREEN_RESOLUTION=2100x2100x24` (квадратный VNC-canvas с запасом под Qt chrome). Skin эмулятора остаётся `1080x1920`.

## VNC / desktop

| Проблема | Фикс |
|---|---|
| Лого растянуто | Wallpaper `aerokube.png` **2100×2100**, Fluxbox `background: aspect` + `feh --bg-center` |
| Маленький phone + пустой desktop | Эмулятор `-fixed-scale` (окно 1:1 к skin `1080x1920`); deco off; raise loop |
| Низ телефона обрезан | Canvas `2100²` = skin + title/toolbar margin (не skin alone `1920²`) |
| Landscape во время сессии | Тот же квадрат вмещает portrait (`~1150×1970`) и landscape (`~1990×1130`); окно pinned **слева снизу** (не прыгает в top-left) |
| Образ в VNC «едет» вверх рывками | `wmctrl -e …,-1,-1` раздувает Qt-окно (~+25px/тик). Pin с **явным** `w,h`, только при смене размера (rotate) |

Пересборка образа нужна для wallpaper/`apps`/entrypoint. Смена только `SCREEN_RESOLUTION` в `browsers.json` — достаточно sync + reload Selenoid config (без rebuild), если image уже с новым entrypoint.

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

## Учебная manual-сессия

1. Открыть Selenoid UI и перейти в **Capabilities**.
2. Выбрать `android` → `16.0`.
3. Включить **VNC** и **Video**, затем нажать **Create Session**.
4. Дождаться cold start (обычно 70–90 секунд) и открыть VNC.
5. После демонстрации завершить сессию. MP4 появится в списке записей Selenoid.

Для демонстрации своего APK добавить capability:

```json
{
  "appium:app": "https://example.org/app-debug.apk",
  "appium:noReset": false
}
```

APK должен быть доступен контейнеру по HTTP(S). Это disposable-сессия: после её
завершения контейнер и установленное приложение удаляются.

Канонический benchmark на самом Selenoid-хосте:

```bash
COUNT=5 ./scripts/smoke-cold.sh http://127.0.0.1:4444/wd/hub

COUNT=1 \
APP_URL=https://github.com/appium/android-apidemos/releases/download/v6.0.1/ApiDemos-debug.apk \
  ./scripts/smoke-cold.sh http://127.0.0.1:4444/wd/hub
```

Скрипт после каждой попытки делает `DELETE session`, ждёт удаления контейнера и в конце проверяет `remaining_android_containers=0`.

## Измеренный cold timeline — prod Linux+KVM

Дата: **2026-07-21**, `selenoid.qa.guru`, then 2 vCPU / 4 GiB (benchmark). Current prod default: **4 vCPU / 6 GiB**, guest `hw.ramSize=6144M`, VNC canvas `2100x2100x24`.

Baseline до оптимизации:

| Milestone от POST | Время |
|---|---:|
| container started | 0.29 s |
| adb device | 19.77 s |
| `sys.boot_completed` | 62.76 s |
| Appium `/status` | 80.77 s |
| `io.appium.settings` installed | 85.08 s |
| UiAutomator2 server/test installed | 104.49–106.29 s |
| UiAutomator2 process | 112.30 s |
| sessionId | **121.18 s** |

После prepared userdata, helper APK bake, batched ADB settings, `skip*` guards и AVD cleanup:

| Milestone от POST | Median 5 cold runs |
|---|---:|
| container started | 0.28 s |
| emulator process | 0.22 s |
| adb device | 12.36 s |
| `sys.boot_completed` | 35.49 s |
| unlock complete | 37.49 s |
| Appium `/status` | 41.98 s |
| UiAutomator2 process | 54.40 s |
| sessionId | **75.22 s** |

POST → sessionId samples: **69.67, 66.22, 78.91, 75.22, 75.92 s**. Median **75.22 s**, p95 nearest-rank **78.91 s**. Цель median ≤90 s выполнена; stretch ≤60 s не выполнен.

Оставшийся cold bottleneck измерен, а не замаскирован таймаутами:

- полный Android boot до `sys.boot_completed`: median **35.49 s**;
- Appium ready → sessionId: около **33.24 s**;
- UiAutomator2 process → sessionId: около **20.82 s**.

Попытка открыть Appium после package-manager/helpers, но до boot completion дала Appium `/status` на 22.92 s, тогда как boot завершился на 38.69 s. UiAutomator2 не инициализировался и исчерпал существующий 180 s launch timeout. Поэтому production gate оставлен на `sys.boot_completed`; таймауты не увеличивались.

Дополнительный prod smoke с `appium:app` URL и `appium:noReset=false`: sessionId **86.10 s**, touch **HTTP 200**, screenshot **HTTP 200**, VNC WebSocket **HTTP 101**. Отдельный `enableVideo=true` smoke создал валидный MP4 (**305,565 bytes**). После всех smoke: hub `used=0`, Android containers `0`.

Registry: `qaguru/android:16` опубликован в Docker Hub, digest
`sha256:566edca29639de108c601b02dbb07495f34e14b5c31c034cab1e8c42aa6a418a`.

## WARM POOL — DEFERRED

Это отдельная архитектурная фаза и **не часть текущей cold-container реализации**. `warm-pool-orchestrator/` здесь не меняется.

Граница будущего плана:

1. persistent booted emulator containers с заранее готовым Appium/UiAutomator2;
2. атомарный lease → use → reset → recycle state machine;
3. health checks для emulator, ADB, boot state, Appium и UiAutomator2;
4. concurrency limits, lease timeout и защита от double allocation;
5. гарантированный cleanup пользовательских APK/data, stale sessions и broken containers;
6. периодический recycle по age/session count и quarantine после failed reset;
7. исследование snapshot restore / prewarmed AVD отдельно от disposable cold image;
8. метрики queue time, lease time, reset time, recycle rate и cold fallback.

Warm pool не должен менять семантику `appium:app`, `noReset=false`, VNC/video или выдавать состояние предыдущего арендатора.

## Вне scope / deferred

- Mac runtime (arm64 / soft accel)
- iOS / XCUITest
- budtmo / Pro
- device farm
- Chrome Mobile / chromedriver в этом образе
