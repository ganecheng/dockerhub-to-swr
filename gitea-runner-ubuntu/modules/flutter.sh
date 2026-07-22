#!/usr/bin/env bash
set -exuo pipefail
source "$(dirname "$0")/common.sh"

JDK_VERSION=21

install_temurin_jdk "$JDK_VERSION"
