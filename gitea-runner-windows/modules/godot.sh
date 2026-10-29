#!/usr/bin/env bash
# 7-Zip + Godot 编辑器与导出模板安装模块 (Git Bash 版)
set -exuo pipefail
source "$(dirname "$0")/common.sh"

install_7zip
install_godot_editor "${GODOT_VERSION:?GODOT_VERSION is required}"
install_godot_export_templates "${GODOT_VERSION}"
