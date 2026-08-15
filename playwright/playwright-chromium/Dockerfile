ARG PLAYWRIGHT_VERSION=1.61.1

# Static CDP proxy for container port 7070 (hub-HAR / se:cdp / /devtools/<id>/).
# Cross-compiled on the build host for the target arch (amd64 + arm64), no CGO.
FROM --platform=$BUILDPLATFORM golang:1.26.5-bookworm AS devtools-proxy
ARG TARGETARCH
WORKDIR /src
COPY shared/devtools-proxy/ ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags='-s -w' -o /devtools-proxy .

FROM mcr.microsoft.com/playwright:v${PLAYWRIGHT_VERSION}-noble

ARG PLAYWRIGHT_VERSION
ARG PW_BROWSER_TYPE=chromium
ARG PW_BROWSER_NAME=Chromium
ARG PW_BROWSER_CHANNEL=

ENV PW_HOST=0.0.0.0 \
    PW_PORT=3000 \
    PW_PATH=/ \
    PW_HEADLESS=true \
    PW_BROWSER_TYPE=${PW_BROWSER_TYPE} \
    PW_BROWSER_NAME=${PW_BROWSER_NAME} \
    PW_BROWSER_CHANNEL=${PW_BROWSER_CHANNEL} \
    DISPLAY=:99 \
    DISPLAY_NUM=99 \
    NODE_PATH=/usr/lib/node_modules

USER root
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        dumb-init \
        x11-utils \
        x11vnc \
        xvfb \
    && npm install -g "playwright-core@${PLAYWRIGHT_VERSION}" \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/playwright /tmp/.X11-unix \
    && chmod 1777 /tmp/.X11-unix

COPY --from=devtools-proxy /devtools-proxy /usr/local/bin/devtools-proxy
COPY shared/common.sh shared/entrypoint.sh shared/server.cjs shared/launch-headed-browser.js /opt/playwright/
RUN chmod +x /opt/playwright/entrypoint.sh

USER pwuser
WORKDIR /home/pwuser

EXPOSE 3000 7070
# VNC 5900 is published by Selenoid via browsers.json, not EXPOSE (docker:S6473).

HEALTHCHECK --interval=5s --timeout=3s --start-period=30s --retries=6 \
    CMD node -e "require('http').get('http://127.0.0.1:3000/',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

LABEL org.opencontainers.image.title="qaguru/playwright-chromium" \
      org.opencontainers.image.source="https://github.com/qa-guru/browser-image" \
      io.qaguru.browser="chromium" \
      io.qaguru.protocol="playwright" \
      io.qaguru.port="3000" \
      io.qaguru.devtools.port="7070"

ENTRYPOINT ["dumb-init", "--", "/opt/playwright/entrypoint.sh"]
