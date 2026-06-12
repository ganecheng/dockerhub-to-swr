FROM ubuntu:resolute-20260421

ENV TZ=Asia/Shanghai
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# 系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    openjdk-21-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

# Android SDK
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools

# https://developer.android.com/studio#command-line-tools-only
ARG CMDLINE_TOOLS_URL=https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip
RUN curl -fsSL ${CMDLINE_TOOLS_URL} -o /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools \
    && mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
    && mv /tmp/cmdline-tools/cmdline-tools/* ${ANDROID_SDK_ROOT}/cmdline-tools/latest/ \
    && rm -rf /tmp/cmdline-tools /tmp/cmdline-tools.zip

ENV PATH="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${PATH}"

# Android SDK 组件 (compileSdk 36, NDK 29, build-tools 36)
# 额外预装传递依赖需要的版本，避免 Gradle 构建时实时下载
RUN yes | sdkmanager --licenses \
    && sdkmanager \
        "platform-tools" \
        "platforms;android-36" \
        "platforms;android-35" \
        "build-tools;36.0.0" \
        "ndk;29.0.14206865" \
        "ndk;28.2.13676358" \
        "cmake;3.22.1" \
    && rm -rf ${ANDROID_SDK_ROOT}/.temp ${ANDROID_SDK_ROOT}/.knownPackages

# Flutter SDK 3.44.1 (Dart >=3.10.0)
ARG FLUTTER_VERSION=3.44.1
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && flutter config --no-analytics \
    && flutter precache --android

# 全局禁用 Gradle Daemon（容器内 daemon fork 会导致构建死锁）
# 降低 JVM 堆上限避免容器 OOM
RUN mkdir -p /root/.gradle \
    && printf 'org.gradle.daemon=false\norg.gradle.jvmargs=-Xmx8096m\n' > /root/.gradle/gradle.properties

WORKDIR /app
