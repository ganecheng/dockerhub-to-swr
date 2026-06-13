# escape=`

FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG FLUTTER_VERSION=3.44.1
ARG GIT_INSTALLATION_PATH="C:\Program Files\Git"

ENV USERPROFILE="C:\Users\ContainerUser"
ENV SDK_ROOT="${USERPROFILE}\sdks"
ENV FLUTTER_ROOT="${SDK_ROOT}\flutter"
ENV FLUTTER_GIT_URL="unknown source"

WORKDIR "$USERPROFILE"

# 安装 MinGit (Flutter 需要)
RUN $installer = \"MinGit-2.54.0-busybox-64-bit.zip\"; `
    $url = \"https://github.com/git-for-windows/git/releases/download/v2.54.0.windows.1/${installer}\"; `
    Invoke-WebRequest -Uri \"$url\" -OutFile \"$installer\"; `
    Expand-Archive -Path \"$installer\" -DestinationPath \"$env:GIT_INSTALLATION_PATH\"; `
    Remove-Item -Path \"$installer\"

USER ContainerAdministrator

# 设置系统 PATH
RUN [Environment]::SetEnvironmentVariable('PATH', \"${env:PATH};${env:GIT_INSTALLATION_PATH}\cmd;${env:GIT_INSTALLATION_PATH}\usr\bin;${env:FLUTTER_ROOT}\bin;${env:FLUTTER_ROOT}\bin\cache\dart-sdk\bin;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\", 'Machine')

# 修复 MinGit 的循环引用问题
RUN $env:GIT_CONFIG_NOSYSTEM=1; git config --system --unset-all include.path

USER ContainerUser

# 克隆 Flutter SDK
RUN git clone --depth 1 --branch \"$env:FLUTTER_VERSION\" https://github.com/flutter/flutter.git \"$env:FLUTTER_ROOT\"; `
    git config --global --add safe.directory \"$env:FLUTTER_ROOT\"; `
    flutter --version; `
    dart --disable-analytics; `
    flutter config --no-cli-animations --no-analytics --no-enable-android --no-enable-web --no-enable-linux-desktop --enable-windows-desktop --no-enable-fuchsia --no-enable-custom-devices --no-enable-ios --no-enable-macos-desktop; `
    flutter doctor --verbose; `
    flutter precache --windows

USER ContainerAdministrator

# 使用 Chocolatey 安装 VS Build Tools（比直接下载更稳定）
RUN $env:chocolateyUseWindowsCompression = 'true'; `
    $env:chocolateyIgnoreRebootDetected = 'true'; `
    choco install visualstudio2022buildtools -y --no-progress --allow-downgrade --package-parameters \"--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041 --add Microsoft.VisualStudio.Component.VC.CMake.Project --passive --locale en-US\"; `
    Remove-Item C:\ProgramData\chocolatey\logs -Recurse -Force -ErrorAction SilentlyContinue

USER ContainerUser

# 禁用 MSBuild 节点复用
RUN setx /M MSBUILDDISABLENODEREUSE 1

WORKDIR C:\app
