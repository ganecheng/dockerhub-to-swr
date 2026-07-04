#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

JDK_VERSION=25
JMETER_VERSION=5.6.3

install_temurin_jdk "$JDK_VERSION"
install_jmeter "$JMETER_VERSION"
