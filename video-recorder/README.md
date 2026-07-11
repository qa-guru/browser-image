# video-recorder

Sidecar-образ для Selenoid: пишет H.264 MP4 с X11-дисплея browser-контейнера в `/data/`.

Часть репозитория [`browser-image`](../README.md). Контракт совместим с legacy `selenoid/video-recorder` (env: `FILE_NAME`, `VIDEO_SIZE`, `FRAME_RATE`, `BROWSER_CONTAINER_NAME`, `DISPLAY`).

| Docker | Назначение |
|--------|------------|
| `qaguru/video-recorder:latest` | sidecar для `enableVideo: true` |
| `qaguru/video-recorder:<version>` | pinned release |

Основа — [aerokube/images/selenium/video](https://github.com/aerokube/images/tree/master/selenium/video) (Apache 2.0): Alpine 3.21, stock ffmpeg, `xdpyinfo` для ожидания дисплея, `-nostdin`.

## Automated Tests Dashboard

[![Video recorder](https://qa-guru.github.io/selenoid-tests/readme/badge-video-recorder.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

[![Video recorder stats](https://qa-guru.github.io/selenoid-tests/readme/stats-video-recorder.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

[![Video recorder metrics](https://qa-guru.github.io/selenoid-tests/readme/metrics-panel-video-recorder.svg)](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/)

<a href="https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://qa-guru.github.io/selenoid-tests/readme/dashboard-preview-video-recorder-dark.png">
    <img
      src="https://qa-guru.github.io/selenoid-tests/readme/dashboard-preview-video-recorder.png"
      alt="Allure 3 dashboard — video-recorder sidecar only (status, pyramid, dynamics, treemap)"
      width="800"
    />
  </picture>
</a>

> Component-filtered dashboard PNG (`@Component video-recorder` only). Updates after each orchestrator run on `main`.

| Link | Description |
|------|-------------|
| [Awesome epic video-recorder](https://qa-guru.github.io/selenoid-tests/reports/latest/awesome/) | Hub `/video` + UI proxy — session MP4 after `enableVideo` |
| [Stack dashboard](https://qa-guru.github.io/selenoid-tests/reports/latest/dashboard/) | Full Selenoid pyramid (all components) |
| [selenoid-tests](https://github.com/qa-guru/selenoid-tests) | Orchestrator + merged Allure (`testVideoRecorder` smoke) |

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
