# escape=`

FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# 系统依赖 — Chocolatey + Git（带重试逻辑应对网络不稳定）
RUN $maxRetries = 5; $retryDelay = 30; $success = $false; `
    for ($i = 1; $i -le $maxRetries; $i++) { `
        try { `
            Write-Host \"Attempt $i of $maxRetries - Installing Chocolatey...\"; `
            Set-ExecutionPolicy Bypass -Scope Process -Force; `
            [System.Net.ServicePointManager]::SecurityProtocol = 3072; `
            iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')); `
            $success = $true; `
            break; `
        } catch { `
            Write-Host \"Chocolatey install failed: $_\"; `
            if ($i -lt $maxRetries) { `
                Write-Host \"Retrying in $retryDelay seconds...\"; `
                Start-Sleep -Seconds $retryDelay; `
            } else { `
                throw \"Failed to install Chocolatey after $maxRetries attempts\"; `
            } `
        } `
    }

RUN $env:chocolateyUseWindowsCompression = 'true'; `
    choco install git -y --no-progress --allow-downgrade; `
    Remove-Item C:\ProgramData\chocolatey\logs -Recurse -Force -ErrorAction SilentlyContinue; `
    Remove-Item C:\Users\ContainerAdministrator\AppData\Local\Temp\chocolatey -Recurse -Force -ErrorAction SilentlyContinue

# Visual Studio Build Tools 2022 — 仅 Flutter Windows 必需的三个组件
# 使用 Windows 10 SDK (19041) 替代 Windows 11 SDK，容器兼容性更好
# 添加重试逻辑和详细日志以应对网络不稳定
RUN [System.Net.ServicePointManager]::SecurityProtocol = 3072; `
    New-Item -ItemType Directory -Force -Path C:\TEMP; `
    $maxRetries = 3; $retryCount = 0; $success = $false; `
    while (-not $success -and $retryCount -lt $maxRetries) { `
        try { `
            Write-Host \"Attempt $(($retryCount + 1)) of $maxRetries - Downloading VS Build Tools...\"; `
            Invoke-WebRequest -Uri \"https://aka.ms/vs/17/release/vs_BuildTools.exe\" `
                -OutFile C:\TEMP\vs_BuildTools.exe -UseBasicParsing; `
            $success = $true; `
        } catch { `
            $retryCount++; `
            if ($retryCount -lt $maxRetries) { Write-Host \"Download failed, retrying in 10 seconds...\"; Start-Sleep -Seconds 10; } `
            else { throw $_; } `
        } `
    }; `
    Write-Host \"Installing VS Build Tools (this may take 30+ minutes)...\"; `
    $process = Start-Process -FilePath C:\TEMP\vs_BuildTools.exe `
        -ArgumentList '--quiet','--wait','--norestart','--nocache',`
            '--installPath','C:\BuildTools',`
            '--add','Microsoft.VisualStudio.Component.VC.Tools.x86.x64',`
            '--add','Microsoft.VisualStudio.Component.Windows10SDK.19041',`
            '--add','Microsoft.VisualStudio.Component.VC.CMake.Project',`
            '--log','C:\TEMP\vs_install.log' `
        -PassThru -NoNewWindow; `
    $process.WaitForExit(); `
    if ($process.ExitCode -notin @(0,3010)) { `
        Write-Host \"Installation failed with exit code: $($process.ExitCode)\"; `
        if (Test-Path C:\TEMP\vs_install.log) { Get-Content C:\TEMP\vs_install.log -Tail 100; } `
        throw \"VS Build Tools installation failed\"; `
    }; `
    Remove-Item C:\TEMP\vs_BuildTools.exe -Force -ErrorAction SilentlyContinue; `
    Remove-Item C:\TEMP\vs_install.log -Force -ErrorAction SilentlyContinue

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
