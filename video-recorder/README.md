# video-recorder

<!-- stack-branches-note:start -->
> **Stack pin:** стабильные сборки всего стека — ветки `selenoid2-1.45-engine26.1-go1.26-react16` (**v2.2.1**, API 1.45 / Engine 26.1.x / Go 1.26.5 / React 16) и `selenoid2-1.55-engine29.6-go1.26-react18` (**v2.3.0**, API 1.55 / Engine 29.6+ / Go 1.26.5 / React 18). Детали — [`STACK-PIN.md`](../STACK-PIN.md) · [корневой README](../README.md) · [monorepo SSOT](https://github.com/qa-guru/zero-design-system/blob/master/projects/selenoid-home/README.md).
<!-- stack-branches-note:end -->


Sidecar-образ для Selenoid: пишет H.264 MP4 с X11-дисплея browser-контейнера в `/data/`.

Часть репозитория [`browser-image`](../README.md). Контракт совместим с legacy `selenoid/video-recorder` (env: `FILE_NAME`, `VIDEO_SIZE`, `FRAME_RATE`, `BROWSER_CONTAINER_NAME`, `DISPLAY`).

| Docker | Назначение |
|--------|------------|
| `qaguru/video-recorder:latest` | sidecar для `enableVideo: true` |
| `qaguru/video-recorder:<version>` | pinned release |

Основа — [aerokube/images/selenium/video](https://github.com/aerokube/images/tree/master/selenium/video) (Apache 2.0): Alpine 3.21, stock ffmpeg, `xdpyinfo` для ожидания дисплея, `-nostdin`.

## Build

```bash
chmod +x scripts/build.sh scripts/push.sh
./scripts/build.sh
./scripts/build.sh 1.0.0
```

## Publish

```bash
docker login
./scripts/push.sh 1.0.0
```

## Release

```bash
git tag video-recorder/1.0.0 && git push origin video-recorder/1.0.0
```

CI (`.github/workflows/publish-video-recorder.yml`) пушит `qaguru/video-recorder:1.0.0` и `:latest`.

## Hub wiring

Selenoid поднимает sidecar при `enableVideo: true`. Образ задаётся флагом:

```bash
selenoid -video-recorder-image qaguru/video-recorder:latest ...
```

CM и dev-скрипты используют тот же ref.

После `git tag video-recorder/<version>` CI пушит образ и дергает `selenoid-tests` deploy-smoke (`testVideoRecorder`: `HubVideoSessionApiTests` + `UiVideoSessionApiTests`).
