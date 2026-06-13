# escape=`

FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# 系统依赖 — Chocolatey + Git（自动重试）
RUN $maxRetries = 5; $retryDelay = 60; `
    for ($i = 1; $i -le $maxRetries; $i++) { `
        try { `
            Write-Host "Attempt $i of $maxRetries - Installing Chocolatey..."; `
            Set-ExecutionPolicy Bypass -Scope Process -Force; `
            [System.Net.ServicePointManager]::SecurityProtocol = 3072; `
            iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')); `
            break; `
        } catch { `
            Write-Host "Chocolatey install failed: $_"; `
            if ($i -lt $maxRetries) { Start-Sleep -Seconds $retryDelay } `
            else { throw "Failed to install Chocolatey after $maxRetries attempts" } `
        } `
    }

# 安装 Git（通过 Chocolatey）
RUN $env:chocolateyUseWindowsCompression = 'true'; `
    $env:chocolateyIgnoreRebootDetected = 'true'; `
    choco feature enable -n=useRememberedArgumentsForUpgrades; `
    choco install git -y --no-progress --allow-downgrade

# Flutter SDK - 使用 git clone（参考 gmeligio/flutter-docker-image）
ARG FLUTTER_VERSION=3.44.1
ENV FLUTTER_ROOT=C:\flutter
ENV FLUTTER_GIT_URL="unknown source"

RUN git clone --depth 1 --branch $env:FLUTTER_VERSION https://github.com/flutter/flutter.git C:\flutter; `
    git config --global --add safe.directory C:\flutter

# 设置 PATH（ENV 在下一个 RUN 才生效）
ENV PATH="C:\flutter\bin;C:\flutter\bin\cache\dart-sdk\bin;${PATH}"

# Flutter 配置
RUN flutter --version; `
    dart --disable-analytics; `
    flutter config --no-cli-animations --no-analytics --no-enable-android --no-enable-web --no-enable-linux-desktop --enable-windows-desktop --no-enable-fuchsia --no-enable-custom-devices --no-enable-ios --no-enable-macos-desktop; `
    flutter doctor --verbose; `
    flutter precache --windows

# 安装 Visual Studio Build Tools 2022 + VC++ 工具链
RUN Invoke-WebRequest -Uri https://aka.ms/vs/17/release/vs_buildtools.exe -OutFile C:\vs_buildtools.exe; `
    Start-Process C:\vs_buildtools.exe -ArgumentList "--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Component.VC.CMake.Project --add Microsoft.VisualStudio.Component.Windows10SDK.19041 --add Microsoft.VisualStudio.Workload.VCTools" -Wait; `
    Remove-Item C:\vs_buildtools.exe -Force -ErrorAction SilentlyContinue

# 禁用 MSBuild 节点复用
RUN setx /M MSBUILDDISABLENODEREUSE 1

WORKDIR C:\app
