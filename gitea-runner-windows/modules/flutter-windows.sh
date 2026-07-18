#!/usr/bin/env bash
# Flutter Windows 构建环境安装模块 (Git Bash 版)
# 对应 Linux 版的 modules/flutter-ubuntu.sh 等模块脚本
# 仅安装 Flutter SDK（VS Build Tools 和 NuGet 已由基础镜像 windows-dev 提供）

set -euo pipefail

# 加载共享函数库（与脚本同目录）
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

install_flutter '3.44.2'