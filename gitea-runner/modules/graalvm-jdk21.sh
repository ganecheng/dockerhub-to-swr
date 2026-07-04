#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

JDK_VERSION=21
MAVEN_VERSION=3.9.9

install_graalvm_jdk "$JDK_VERSION"
install_maven "$MAVEN_VERSION"
