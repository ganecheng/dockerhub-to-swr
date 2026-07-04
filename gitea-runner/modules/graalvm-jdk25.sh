#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

JDK_VERSION=25
MAVEN_VERSION=3.9.9

install_graalvm_jdk "$JDK_VERSION"
export JAVA_HOME="/opt/graalvm-jdk-${JDK_VERSION}"
install_maven "$MAVEN_VERSION"
