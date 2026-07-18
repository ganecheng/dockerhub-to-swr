# escape=`

FROM ghcr.io/ganecheng/windows:20260614_200825-windows-x86_64

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG FLUTTER_VERSION=3.44.2

ENV FLUTTER_ROOT="C:\flutter"
ENV FLUTTER_GIT_URL="unknown source"
ENV PUB_CACHE="C:\pub-cache"

WORKDIR "C:\app"

# 将 Flutter/Dart 路径追加到系统 PATH（Git 等路径已由基础镜像设置）
RUN [Environment]::SetEnvironmentVariable('PATH', \"${env:PATH};${env:FLUTTER_ROOT}\bin;${env:FLUTTER_ROOT}\bin\cache\dart-sdk\bin\", 'Machine')

# 克隆 Flutter SDK，预缓存 Windows 引擎，然后清理不必要的文件以减小镜像体积
RUN git clone --depth 1 --branch "$env:FLUTTER_VERSION" https://github.com/flutter/flutter.git "$env:FLUTTER_ROOT"; `
    git config --global --add safe.directory "$env:FLUTTER_ROOT"; `
    flutter --version; `
    dart --disable-analytics; `
    flutter config --no-cli-animations --no-analytics --no-enable-android --no-enable-web --no-enable-linux-desktop --enable-windows-desktop --no-enable-fuchsia --no-enable-custom-devices --no-enable-ios --no-enable-macos-desktop; `
    flutter precache --windows; `
    # 清理示例和开发文档（节省 ~200MB）
    Remove-Item -Recurse -Force "$env:FLUTTER_ROOT\examples" -ErrorAction SilentlyContinue; `
    Remove-Item -Recurse -Force "$env:FLUTTER_ROOT\dev" -ErrorAction SilentlyContinue; `
    # 清理临时缓存
    Remove-Item -Recurse -Force "$env:FLUTTER_ROOT\bin\cache\pkg" -ErrorAction SilentlyContinue; `
    Remove-Item -Recurse -Force "$env:FLUTTER_ROOT\bin\cache\flutter_tools.skps" -ErrorAction SilentlyContinue; `
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue