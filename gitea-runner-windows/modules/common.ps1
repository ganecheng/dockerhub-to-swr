﻿# 共享安装函数库：Web 下载封装、Flutter 安装
# 对应 Linux 版的 modules/common.sh
# VS Build Tools 和 NuGet 已由基础镜像 (windows-dev) 提供，无需在此安装

# 封装 Invoke-WebRequest：统一超时和重试策略
function Invoke-WebRequestSafe {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$OutFile
    )
    $maxRetries = 3
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
            return
        } catch {
            if ($i -eq $maxRetries - 1) { throw }
            Write-Host "Retry $($i + 1)/$maxRetries after error: $_"
            Start-Sleep -Seconds 5
        }
    }
}

# 安装 Flutter SDK（仅启用 Windows 桌面构建）
# 参数: $Version - Flutter 版本号 (如 3.44.2)
# 需要预先通过 Dockerfile ENV 设置 FLUTTER_ROOT 和 PATH
function Install-Flutter {
    param([string]$Version = '3.44.2')

    # Docker ENV 设置的是进程级环境变量，优先从 $env: 读取
    $flutterRoot = $env:FLUTTER_ROOT
    if (-not $flutterRoot) { $flutterRoot = 'C:\flutter' }

    Write-Host ">>> Installing Flutter $Version to $flutterRoot..."

    git clone --depth 1 --branch $Version https://github.com/flutter/flutter.git $flutterRoot
    git config --global --add safe.directory $flutterRoot

    flutter --version
    dart --disable-analytics
    flutter config --no-cli-animations --no-analytics `
        --no-enable-android --no-enable-web --no-enable-linux-desktop `
        --enable-windows-desktop --no-enable-fuchsia --no-enable-custom-devices `
        --no-enable-ios --no-enable-macos-desktop
    flutter precache --windows

    # 清理示例和开发文档（节省 ~200MB）
    Remove-Item -Recurse -Force "$flutterRoot\examples" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$flutterRoot\dev" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$flutterRoot\bin\cache\pkg" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$flutterRoot\bin\cache\flutter_tools.skps" -ErrorAction SilentlyContinue
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue

    Write-Host ">>> Flutter $Version installed"
}
