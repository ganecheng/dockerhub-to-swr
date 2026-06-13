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
    choco install git -y --no-progress --allow-downgrade; `
    Remove-Item C:\ProgramData\chocolatey\logs -Recurse -Force -ErrorAction SilentlyContinue; `
    Remove-Item C:\Users\ContainerAdministrator\AppData\Local\Temp\chocolatey -Recurse -Force -ErrorAction SilentlyContinue

# Flutter SDK 3.44.1 (Dart >=3.10.0)
ARG FLUTTER_VERSION=3.44.1
ENV FLUTTER_HOME=C:\flutter
ENV FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_${FLUTTER_VERSION}-stable.zip"
ENV PATH="C:\flutter\bin;${PATH}"

RUN New-Item -ItemType Directory -Force -Path C:\TEMP | Out-Null; `
    Invoke-WebRequest -Uri $env:FLUTTER_URL -OutFile C:\TEMP\flutter.zip; `
    Expand-Archive C:\TEMP\flutter.zip -DestinationPath C:\; `
    Remove-Item C:\TEMP\flutter.zip -Force; `
    flutter config --no-analytics; `
    flutter precache --windows

# 安装 Visual Studio Build Tools 2022 + VC++ 工具链
# 参考: https://learn.microsoft.com/en-us/visualstudio/install/build-tools-container
RUN Invoke-WebRequest -Uri https://aka.ms/vs/17/release/vs_buildtools.exe -OutFile C:\TEMP\vs_buildtools.exe; `
    Start-Process C:\TEMP\vs_buildtools.exe -ArgumentList "--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Component.VC.CMake.Project --add Microsoft.VisualStudio.Component.Windows10SDK.19041 --add Microsoft.VisualStudio.Workload.VCTools" -Wait; `
    Remove-Item C:\TEMP\vs_buildtools.exe -Force -ErrorAction SilentlyContinue

# 禁用 MSBuild 节点复用（容器内复用会导致构建卡死）
RUN setx /M MSBUILDDISABLENODEREUSE 1

WORKDIR C:\app
