#!/usr/bin/env bash
# Node.js + Gitea Runner 安装模块 (Git Bash 版)
# 对应基础镜像 Dockerfile 的安装逻辑
# VS Build Tools、NuGet、Git 已由基础镜像 (windows) 提供

set -euo pipefail

# 加载共享函数库（与脚本同目录）
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

install_node "${NODE_VERSION:?NODE_VERSION is required}"
install_gitea_runner "${GITEA_RUNNER_VERSION:?GITEA_RUNNER_VERSION is required}"
