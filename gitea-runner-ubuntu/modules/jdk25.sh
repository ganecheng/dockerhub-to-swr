#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

JDK_VERSION=25
MAVEN_VERSION=3.9.9

install_temurin_jdk "$JDK_VERSION"
export JAVA_HOME="/opt/jdk-${JDK_VERSION}"
install_maven "$MAVEN_VERSION"
