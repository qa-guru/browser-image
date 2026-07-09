#!/bin/sh
# Fork of aerokube/images selenium/video — Selenoid sidecar contract preserved.
set -e

VIDEO_SIZE="${VIDEO_SIZE:-1920x1080}"
BROWSER_CONTAINER_NAME="${BROWSER_CONTAINER_NAME:-browser}"
DISPLAY_NUM="${DISPLAY:-99}"
FILE_NAME="${FILE_NAME:-video.mp4}"
FRAME_RATE="${FRAME_RATE:-12}"
CODEC="${CODEC:-libx264}"
PRESET="${PRESET:-}"
DISPLAY_WAIT_TIMEOUT="${DISPLAY_WAIT_TIMEOUT:-30}"
INPUT_OPTIONS="${INPUT_OPTIONS:-}"
HIDE_CURSOR="${HIDE_CURSOR:-}"

if [ "$CODEC" = "libx264" ] && [ -n "$PRESET" ]; then
    PRESET_ARG="-preset $PRESET"
else
    PRESET_ARG=""
fi

if [ -n "$HIDE_CURSOR" ]; then
    INPUT_OPTIONS="$INPUT_OPTIONS -draw_mouse 0"
fi

BROWSER_DISPLAY="${BROWSER_CONTAINER_NAME}:${DISPLAY_NUM}"

retries=$((DISPLAY_WAIT_TIMEOUT * 10))
attempt=0
echo "Waiting for X11 display ${BROWSER_DISPLAY}..."
while [ "$attempt" -lt "$retries" ]; do
    if xdpyinfo -display "$BROWSER_DISPLAY" >/dev/null 2>&1; then
        echo "Display ${BROWSER_DISPLAY} is ready"
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.1
done

if [ "$attempt" -eq "$retries" ]; then
    echo "ERROR: display ${BROWSER_DISPLAY} did not become available within ${DISPLAY_WAIT_TIMEOUT}s" >&2
    exit 1
fi

mkdir -p ~/.config/pulse
echo -n 'gIBAgICAgIBAgICAgIBAgA==' | base64 -d > ~/.config/pulse/cookie 2>/dev/null || true
export PULSE_SERVER="$BROWSER_CONTAINER_NAME"

if pactl info >/dev/null 2>&1; then
    echo "PulseAudio available — recording video with audio"
    # shellcheck disable=SC2086
    exec ffmpeg -nostdin \
        -f pulse -thread_queue_size 1024 -i default \
        -y -f x11grab -video_size "$VIDEO_SIZE" -r "$FRAME_RATE" \
        $INPUT_OPTIONS \
        -i "$BROWSER_DISPLAY" \
        -c:v "$CODEC" $PRESET_ARG -pix_fmt yuv420p \
        -filter:v "pad=ceil(iw/2)*2:ceil(ih/2)*2" \
        "/data/${FILE_NAME}"
else
    echo "PulseAudio not available — recording video only"
    # shellcheck disable=SC2086
    exec ffmpeg -nostdin \
        -y -f x11grab -video_size "$VIDEO_SIZE" -r "$FRAME_RATE" \
        $INPUT_OPTIONS \
        -i "$BROWSER_DISPLAY" \
        -c:v "$CODEC" $PRESET_ARG -pix_fmt yuv420p \
        -filter:v "pad=ceil(iw/2)*2:ceil(ih/2)*2" \
        "/data/${FILE_NAME}"
fi
