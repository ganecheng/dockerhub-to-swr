#!/usr/bin/env bash
# 共享安装函数库 (Git Bash 版)：Web 下载封装、Node.js/Gitea Runner/Flutter 安装
# 对应 Linux 版的 modules/common.sh
# VS Build Tools 和 NuGet 已由基础镜像 (windows) 提供，无需在此安装

set -euo pipefail

# 封装 curl：统一超时和重试策略（与基础镜像 Dockerfile 一致）
function curl() {
  command curl -sSfL --connect-timeout 10 --max-time 300 --retry 3 --retry-all-errors "$@"
}

# 安装 Flutter SDK（仅启用 Windows 桌面构建）
# 参数: $1 - Flutter 版本号 (如 3.44.2)
# 需要预先通过 Dockerfile ENV 设置 FLUTTER_ROOT 和 PATH
function install_flutter() {
  local version=${1:-3.44.2}
  # Docker ENV 设置的是进程级环境变量，优先读取
  local flutter_root=${FLUTTER_ROOT:-C:/flutter}

  echo ">>> Installing Flutter $version to $flutter_root..."

  # 路径以正斜杠形式提供给 Windows 原生 git.exe，避免 bash 反斜杠转义陷阱；
  # Git Bash 会自动将 C:/... 路径作为 Windows 路径传递给 git.exe。
  git clone --depth 1 --branch "$version" https://github.com/flutter/flutter.git "$flutter_root"
  git config --global --add safe.directory "$flutter_root"

  flutter --version
  dart --disable-analytics
  flutter config --no-cli-animations --no-analytics \
    --no-enable-android --no-enable-web --no-enable-linux-desktop \
    --enable-windows-desktop --no-enable-fuchsia --no-enable-custom-devices \
    --no-enable-ios --no-enable-macos-desktop
  flutter precache --windows

  # 清理示例和开发文档（节省 ~200MB）
  rm -rf \
    "$flutter_root/examples" \
    "$flutter_root/dev" \
    "$flutter_root/bin/cache/pkg" \
    "$flutter_root/bin/cache/flutter_tools.skps"

  echo ">>> Flutter $version installed"
}

# 安装 Node.js（GitHub Actions 运行时依赖）
# 参数: $1 - Node.js 版本号 (如 24.18.0)
# 安装路径: 通过 NODE_HOME 环境变量指定 (默认 C:/Program Files/nodejs)
function install_node() {
  local version=${1:?}
  local arch
  arch=$(uname -m)
  local node_arch
  case "$arch" in
    x86_64|amd64)  node_arch="x64" ;;
    aarch64|arm64) node_arch="arm64" ;;
    *) echo "ERROR: Unsupported architecture: $arch" >&2; exit 1 ;;
  esac

  local node_home=${NODE_HOME:-C:/Program Files/nodejs}
  local tmp_dir=C:/tmp/node-install

  echo ">>> Installing Node.js $version ($node_arch) to $node_home..."

  mkdir -p "$tmp_dir"
  curl "https://nodejs.org/dist/v${version}/node-v${version}-win-${node_arch}.zip" -o "$tmp_dir/node.zip"

  # 使用 PowerShell 解压 zip（Git Bash 自带的 GNU tar 不支持 zip 格式）
  pwsh -NoProfile -Command "Expand-Archive -Path '$tmp_dir/node.zip' -DestinationPath '$tmp_dir/extracted' -Force"

  mkdir -p "$node_home"
  cp -r "$tmp_dir/extracted/node-v${version}-win-${node_arch}/"* "$node_home/"
  rm -rf "$tmp_dir"

  echo ">>> Node.js $version installed:"
  "$node_home/node.exe" --version
  "$node_home/npm.cmd" --version
}

# 安装 Gitea Runner
# 参数: $1 - Gitea Runner 版本号 (如 1.0.8)
# 安装路径: 通过 GITEA_RUNNER_HOME 环境变量指定 (默认 C:/opt/bin)
function install_gitea_runner() {
  local version=${1:?}
  local arch
  arch=$(uname -m)
  local runner_arch
  case "$arch" in
    x86_64|amd64)  runner_arch="amd64" ;;
    aarch64|arm64) runner_arch="arm64" ;;
    *) echo "ERROR: Unsupported architecture: $arch" >&2; exit 1 ;;
  esac

  local runner_home=${GITEA_RUNNER_HOME:-C:/opt/bin}

  echo ">>> Installing Gitea Runner $version ($runner_arch) to $runner_home..."

  mkdir -p "$runner_home"
  curl "https://gitea.com/gitea/runner/releases/download/v${version}/gitea-runner-${version}-windows-${runner_arch}.exe" -o "$runner_home/gitea-runner.exe"

  echo ">>> Gitea Runner $version installed:"
  "$runner_home/gitea-runner.exe" --version
}