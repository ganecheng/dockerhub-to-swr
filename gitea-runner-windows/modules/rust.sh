#!/usr/bin/env bash
# Rust 工具链 + cargo-packager + NSIS 缓存安装模块 (Git Bash 版)
set -exuo pipefail
source "$(dirname "$0")/common.sh"

install_rust_toolchain "${RUST_VERSION:?RUST_VERSION is required}"
install_ninja
install_cargo_packager "${CARGO_PACKAGER_VERSION:?CARGO_PACKAGER_VERSION is required}"
install_nsis_cache
