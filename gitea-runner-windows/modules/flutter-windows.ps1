﻿# Flutter Windows 构建环境安装模块
# 对应 Linux 版的 modules/jdk21.sh 等模块脚本
# 仅安装 Flutter SDK（VS Build Tools 和 NuGet 已由基础镜像 windows-dev 提供）

. (Join-Path $PSScriptRoot 'common.ps1')

Install-Flutter -Version '3.44.2'
