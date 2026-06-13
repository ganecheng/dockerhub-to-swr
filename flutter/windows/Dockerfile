# escape=`

# 使用微软预构建镜像（已包含 MSBuild、.NET Framework SDK）
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG FLUTTER_VERSION=3.44.1
ARG GIT_INSTALLATION_PATH="C:\Program Files\Git"

ENV USERPROFILE="C:\Users\ContainerUser"
ENV SDK_ROOT="${USERPROFILE}\sdks"
ENV FLUTTER_ROOT="${SDK_ROOT}\flutter"
ENV FLUTTER_GIT_URL="unknown source"

WORKDIR "$USERPROFILE"

# 安装 MinGit（直接下载，无需 Chocolatey）
RUN $installer = \"MinGit-2.54.0-busybox-64-bit.zip\"; `
    $url = \"https://github.com/git-for-windows/git/releases/download/v2.54.0.windows.1/${installer}\"; `
    Invoke-WebRequest -Uri \"$url\" -OutFile \"$installer\"; `
    Expand-Archive -Path \"$installer\" -DestinationPath \"$env:GIT_INSTALLATION_PATH\"; `
    Remove-Item -Path \"$installer\" 

USER ContainerAdministrator

# 设置系统 PATH
RUN [Environment]::SetEnvironmentVariable('PATH', \"${env:PATH};${env:GIT_INSTALLATION_PATH}\cmd;${env:GIT_INSTALLATION_PATH}\usr\bin;${env:FLUTTER_ROOT}\bin;${env:FLUTTER_ROOT}\bin\cache\dart-sdk\bin\", 'Machine')

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

# 安装 VC++ 工具链（使用 VS Build Tools 安装程序，只安装必要组件）
RUN Invoke-WebRequest -Uri https://aka.ms/vs/17/release/vs_buildtools.exe -OutFile C:\vs_buildtools.exe; `
    Start-Process C:\vs_buildtools.exe -ArgumentList \"--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041\" -Wait; `
    Remove-Item C:\vs_buildtools.exe -Force -ErrorAction SilentlyContinue

USER ContainerUser

# 禁用 MSBuild 节点复用
RUN setx /M MSBUILDDISABLENODEREUSE 1

WORKDIR C:\app
