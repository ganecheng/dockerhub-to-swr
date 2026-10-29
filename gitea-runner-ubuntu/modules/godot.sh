#!/usr/bin/env bash
# Godot 编辑器 + 导出模板安装模块
set -exuo pipefail
source "$(dirname "$0")/common.sh"

install_godot_editor "${GODOT_VERSION:?GODOT_VERSION is required}"
install_godot_export_templates "${GODOT_VERSION}"
