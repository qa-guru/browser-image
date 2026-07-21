# qaguru/android — educational Selenoid Android node (Appium + UiAutomator2 + AVD).
# Runtime: Linux host with /dev/kvm only. Mac: build linux/amd64 OK; sessions — later / deferred.
# No budtmo / sponsor Pro blobs. Not an Android device farm.

FROM ubuntu:22.04 AS android-base

ARG DEBIAN_FRONTEND=noninteractive
# Stack canon: Node 24 (same as selenoid-ui CI). Appium 3 requires Node ^20.19 || ^22.12 || >=24.
ARG APPIUM_VERSION=3.5.2
ARG UIAUTOMATOR2_VERSION=8.1.0
ARG ANDROID_CMDTOOLS_VERSION=11076708
ARG AVD_NAME=android16
ARG PLATFORM=android-36
ARG EMULATOR_IMAGE_TYPE=google_apis
ARG ANDROID_ABI=x86_64
ARG BUILD_TOOLS=build-tools;35.0.0
ARG SDCARD_SIZE=512
ARG USERDATA_SIZE=1536

ENV ANDROID_HOME=/opt/android-sdk-linux \
    ANDROID_SDK_ROOT=/opt/android-sdk-linux \
    AVD_NAME=${AVD_NAME} \
    PLATFORM=${PLATFORM} \
    EMULATOR_IMAGE_TYPE=${EMULATOR_IMAGE_TYPE} \
    ANDROID_ABI=${ANDROID_ABI} \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

ENV PATH=${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/emulator:${ANDROID_HOME}/platform-tools:/opt/node_modules/.bin:${PATH} \
    LD_LIBRARY_PATH=${ANDROID_HOME}/emulator/lib64:${ANDROID_HOME}/emulator/lib64/gles_swiftshader:${ANDROID_HOME}/emulator/lib64/qt/lib:${ANDROID_HOME}/emulator/lib64/vulkan

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gnupg \
      iproute2 \
      openjdk-17-jdk-headless \
      unzip \
      xvfb \
      x11vnc \
      fluxbox \
      wmctrl \
      feh \
      libpulse0 \
      libxcomposite1 \
      libxcursor1 \
      libxi6 \
      libasound2 \
      libnss3 \
      libnspr4 \
      libxcb1 \
      libxkbcommon0 \
      libglib2.0-0 \
      libdbus-1-3 \
      libc++1 \
      e2fsprogs \
    && curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && JAVA_HOME_RESOLVED="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")" \
    && test -d "${JAVA_HOME_RESOLVED}" \
    && ln -sfn "${JAVA_HOME_RESOLVED}" /opt/java-home \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/*

ENV JAVA_HOME=/opt/java-home

RUN npm install --prefix /opt "appium@${APPIUM_VERSION}" \
    && /opt/node_modules/.bin/appium driver install "uiautomator2@${UIAUTOMATOR2_VERSION}"

COPY android.conf /etc/ld.so.conf.d/android.conf
COPY fluxbox/aerokube /usr/share/fluxbox/styles/aerokube
COPY fluxbox/init /root/.fluxbox/init
COPY fluxbox/aerokube.png /usr/share/images/fluxbox/aerokube.png

RUN mkdir -p /opt/android-sdk-linux /root/.config/"Android Open Source Project" \
    && curl -fsSL -o /tmp/cmdline-tools.zip \
         "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDTOOLS_VERSION}_latest.zip" \
    && mkdir -p /opt/android-sdk-linux/cmdline-tools \
    && unzip -q /tmp/cmdline-tools.zip -d /opt/android-sdk-linux/cmdline-tools \
    && mv /opt/android-sdk-linux/cmdline-tools/cmdline-tools /opt/android-sdk-linux/cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip \
    && yes | sdkmanager --licenses >/dev/null \
    && ldconfig

ARG EMULATOR_IMAGE=system-images;${PLATFORM};${EMULATOR_IMAGE_TYPE};${ANDROID_ABI}

RUN sdkmanager --install \
      "emulator" \
      "platform-tools" \
      "${BUILD_TOOLS}" \
      "platforms;${PLATFORM}" \
      "${EMULATOR_IMAGE}"

# Prefer config.ini disk size over qemu-img resize (qemu-img breaks under Rosetta on Mac builds).
RUN mksdcard "${SDCARD_SIZE}M" /sdcard.img \
    && echo "no" | avdmanager create avd \
         -n "${AVD_NAME}" \
         -k "${EMULATOR_IMAGE}" \
         --abi "${ANDROID_ABI}" \
         --device pixel_6 \
    && test -d "/root/.android/avd/${AVD_NAME}.avd" \
    && conf="/root/.android/avd/${AVD_NAME}.avd/config.ini" \
    && if grep -q '^disk.dataPartition.size=' "$conf" 2>/dev/null; then \
         sed -i "s/^disk.dataPartition.size=.*/disk.dataPartition.size=${USERDATA_SIZE}M/" "$conf"; \
       else \
         echo "disk.dataPartition.size=${USERDATA_SIZE}M" >> "$conf"; \
       fi \
    && if [ -f "/root/.android/avd/${AVD_NAME}.avd/userdata.img" ]; then \
         mv "/root/.android/avd/${AVD_NAME}.avd/userdata.img" \
            "/root/.android/avd/${AVD_NAME}.avd/userdata-qemu.img"; \
       fi \
    && sed -i \
         -e 's/^hw.audioInput=.*/hw.audioInput=no/' \
         -e 's/^hw.audioOutput=.*/hw.audioOutput=no/' \
         -e 's/^hw.camera.back=.*/hw.camera.back=none/' \
         -e 's/^hw.cpu.ncore=.*/hw.cpu.ncore=2/' \
         -e 's/^hw.gpu.enabled=.*/hw.gpu.enabled=yes/' \
         -e 's/^hw.gpu.mode=.*/hw.gpu.mode=swiftshader_indirect/' \
         -e 's/^showDeviceFrame=.*/showDeviceFrame=no/' \
         "$conf" \
    && rm -f "${ANDROID_HOME}/system-images/${PLATFORM}/${EMULATOR_IMAGE_TYPE}/${ANDROID_ABI}/userdata.img" \
    && rm -rf /tmp/* /root/.android/cache

COPY Emulator.conf /tmp/Emulator.conf
COPY entrypoint.sh /entrypoint.sh
COPY scripts/prepare-avd.sh /prepare-avd.sh
RUN mkdir -p "/root/.config/Android Open Source Project" \
    && mv /tmp/Emulator.conf "/root/.config/Android Open Source Project/Emulator.conf" \
    && chmod +x /entrypoint.sh /prepare-avd.sh

EXPOSE 4444 5900

ENTRYPOINT ["/entrypoint.sh"]

# Production target. `scripts/prepare-image.sh` creates this deterministic
# userdata on Linux+KVM; Docker commit is deliberately not part of the flow.
FROM android-base AS prepared-runtime

COPY prepared/android16.avd/ /root/.android/avd/android16.avd/
COPY prepared/android16.ini /root/.android/avd/android16.ini
COPY prepared/manifest.env /opt/qaguru/prepared-avd.env

RUN test -s /root/.android/avd/android16.avd/userdata-qemu.img \
    && test -s /opt/qaguru/prepared-avd.env \
    && rm -f /root/.android/avd/android16.avd/*.lock
