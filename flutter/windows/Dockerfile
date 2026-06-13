# escape=`

FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# 系统依赖 — Chocolatey + Git + VS Build Tools（全部通过 Chocolatey 安装，自动重试）
RUN $maxRetries = 5; $retryDelay = 60; `
    for ($i = 1; $i -le $maxRetries; $i++) { `
        try { `
            Write-Host \"Attempt $i of $maxRetries - Installing Chocolatey...\"; `
            Set-ExecutionPolicy Bypass -Scope Process -Force; `
            [System.Net.ServicePointManager]::SecurityProtocol = 3072; `
            iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')); `
            break; `
        } catch { `
            Write-Host \"Chocolatey install failed: $_\"; `
            if ($i -lt $maxRetries) { Start-Sleep -Seconds $retryDelay } `
            else { throw \"Failed to install Chocolatey after $maxRetries attempts\" } `
        } `
    }

# 安装 Git 和 Visual Studio Build Tools 2022（通过 Chocolatey，内置重试机制）
RUN $env:chocolateyUseWindowsCompression = 'true'; `
    $env:chocolateyIgnoreRebootDetected = 'true'; `
    choco feature enable -n=useRememberedArgumentsForUpgrades; `
    choco install git visualstudio2022buildtools -y --no-progress --allow-downgrade; `
    choco install visualstudio2022-workload-vctools -y --no-progress --allow-downgrade `
        --package-parameters \"--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041 --add Microsoft.VisualStudio.Component.VC.CMake.Project --passive --locale en-US\"; `
    Remove-Item C:\ProgramData\chocolatey\logs -Recurse -Force -ErrorAction SilentlyContinue; `
    Remove-Item C:\Users\ContainerAdministrator\AppData\Local\Temp\chocolatey -Recurse -Force -ErrorAction SilentlyContinue; `
    Remove-Item C:\ProgramData\Package Cache -Recurse -Force -ErrorAction SilentlyContinue

# Flutter SDK 3.44.1 (Dart >=3.10.0)
ARG FLUTTER_VERSION=3.44.1
ENV FLUTTER_HOME=C:\flutter
ENV FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_${FLUTTER_VERSION}-stable.zip"
ENV PATH="C:\flutter\bin;${PATH}"

RUN New-Item -ItemType Directory -Force -Path C:\TEMP; `
    Invoke-WebRequest -Uri $env:FLUTTER_URL -OutFile C:\TEMP\flutter.zip; `
    Expand-Archive C:\TEMP\flutter.zip -DestinationPath C:\; `
    Remove-Item C:\TEMP\flutter.zip -Force; `
    flutter config --no-analytics; `
    flutter precache --windows

# 禁用 MSBuild 节点复用（容器内复用会导致构建卡死，等效于 Linux 的 Gradle Daemon）
RUN setx /M MSBUILDDISABLENODEREUSE 1

WORKDIR C:\app
