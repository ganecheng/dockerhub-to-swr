#!/usr/bin/env bash
# 共享安装函数库 (Git Bash 版)：Web 下载封装、Flutter 安装
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