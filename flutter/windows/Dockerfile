# escape=`

FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# 系统依赖 — Chocolatey + Git
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; `
    [System.Net.ServicePointManager]::SecurityProtocol = 3072; `
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

RUN choco install git -y --no-progress; `
    Remove-Item C:\ProgramData\chocolatey\logs -Recurse -Force -ErrorAction SilentlyContinue; `
    Remove-Item C:\Users\ContainerAdministrator\AppData\Local\Temp\chocolatey -Recurse -Force -ErrorAction SilentlyContinue

# Visual Studio Build Tools 2022 (MSVC v143 + Windows SDK + CMake)
# Flutter Windows 构建唯一需要的 VS 工作负载
RUN Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vs_BuildTools.exe" `
        -OutFile C:\TEMP\vs_BuildTools.exe; `
    C:\TEMP\vs_BuildTools.exe --quiet --wait --norestart --nocache `
        --installPath "C:\BuildTools" `
        --add Microsoft.VisualStudio.Workload.VCTools `
        --includeRecommended; `
    Remove-Item C:\TEMP\vs_BuildTools.exe -Force; `
    Remove-Item C:\Windows\Temp\* -Recurse -Force -ErrorAction SilentlyContinue

# Flutter SDK 3.44.1 (Dart >=3.10.0)
ARG FLUTTER_VERSION=3.44.1
ENV FLUTTER_HOME=C:\flutter
ENV FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_${FLUTTER_VERSION}-stable.zip"
ENV PATH="C:\flutter\bin;${PATH}"

RUN Invoke-WebRequest -Uri $env:FLUTTER_URL -OutFile C:\TEMP\flutter.zip; `
    Expand-Archive C:\TEMP\flutter.zip -DestinationPath C:\; `
    Remove-Item C:\TEMP\flutter.zip -Force; `
    flutter config --no-analytics; `
    flutter precache --windows

# 禁用 MSBuild 节点复用（容器内复用会导致构建卡死，等效于 Linux 的 Gradle Daemon）
RUN setx /M MSBUILDDISABLENODEREUSE 1

WORKDIR C:\app
