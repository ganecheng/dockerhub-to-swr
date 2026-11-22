#!/usr/bin/env bash
# Rust 工具链 + cargo-packager + AppImage 工具缓存安装模块
set -exuo pipefail
source "$(dirname "$0")/common.sh"

install_rust_toolchain "${RUST_VERSION:?RUST_VERSION is required}"
install_cargo_packager "${CARGO_PACKAGER_VERSION:?CARGO_PACKAGER_VERSION is required}"
install_appimage_tools
