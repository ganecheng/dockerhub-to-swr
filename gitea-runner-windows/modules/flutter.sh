#!/usr/bin/env bash
# Flutter Windows 构建环境安装模块 (Git Bash 版)
# 对应 Linux 版 (gitea-runner-ubuntu) 的 Flutter 安装逻辑
# 仅安装 Flutter SDK（VS Build Tools 和 NuGet 已由基础镜像 windows 提供）

set -exuo pipefail

# 加载共享函数库（与脚本同目录）
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

# 先下载 CA 证书包，确保后续 Flutter/Dart HTTPS 下载能通过 TLS 验证
install_ca_certificates
install_flutter "${FLUTTER_VERSION:?FLUTTER_VERSION is required}"
