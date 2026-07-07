ARG PLAYWRIGHT_VERSION=1.61.1
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

COPY shared/common.sh shared/entrypoint.sh shared/server.cjs shared/launch-headed-browser.js /opt/playwright/
RUN chmod +x /opt/playwright/entrypoint.sh

USER pwuser
WORKDIR /home/pwuser

EXPOSE 3000 5900

HEALTHCHECK --interval=5s --timeout=3s --start-period=30s --retries=6 \
    CMD node -e "require('http').get('http://127.0.0.1:3000/',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

LABEL org.opencontainers.image.title="qaguru/playwright-chromium" \
      org.opencontainers.image.source="https://github.com/qa-guru/browser-image" \
      io.qaguru.browser="chromium" \
      io.qaguru.protocol="playwright" \
      io.qaguru.port="3000"

ENTRYPOINT ["dumb-init", "--", "/opt/playwright/entrypoint.sh"]
