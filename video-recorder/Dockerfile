FROM alpine:3.21

RUN apk add --no-cache \
    ffmpeg \
    ffmpeg-libavdevice \
    x264-libs \
    pulseaudio-utils \
    xdpyinfo

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
