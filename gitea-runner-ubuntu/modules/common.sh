#!/usr/bin/env bash
# 共享安装函数库：架构检测、JDK/GraalVM/Maven/JMeter/Godot 安装
set -exuo pipefail

# 封装 curl：统一超时和重试策略（与基础镜像 Dockerfile 一致）
function curl() {
  command curl -sSfL --connect-timeout 10 --max-time 300 --retry 3 --retry-all-errors "$@"
}

# 按优先级依次尝试多个下载源，任一成功即返回
# 参数: $1 - 输出文件路径; 其余 - 候选 URL
function download_first_available() {
  local out=${1:?}
  shift
  local url
  for url in "$@"; do
    echo ">>> Downloading ${url}"
    if curl "$url" -o "$out"; then
      return 0
    fi
    echo ">>> WARNING: download failed, trying next source..." >&2
  done
  echo "ERROR: all sources failed" >&2
  return 1
}

# 架构检测：将 uname -m 映射为 JDK 下载所需的架构标识
function detect_jdk_arch() {
  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64)  echo "x64" ;;
    aarch64) echo "aarch64" ;;
    *) echo "ERROR: Unsupported architecture: $arch" >&2; exit 1 ;;
  esac
}

# 安装 Eclipse Temurin (Adoptium) JDK
# 参数: $1 - JDK 主版本号 (如 21, 25)
# 安装路径: /opt/jdk-{version}
function install_temurin_jdk() {
  local version=${1:?}
  local jdk_arch
  jdk_arch=$(detect_jdk_arch)

  echo ">>> Installing Eclipse Temurin JDK ${version} (arch: ${jdk_arch})..."
  curl "https://api.adoptium.net/v3/binary/latest/${version}/ga/linux/${jdk_arch}/jdk/hotspot/normal/eclipse" -o /tmp/jdk.tar.gz
  mkdir -p "/opt/jdk-${version}"
  tar -xzf /tmp/jdk.tar.gz --strip-components=1 -C "/opt/jdk-${version}"
  rm -f /tmp/jdk.tar.gz

  echo ">>> JDK ${version} installed:"
  "/opt/jdk-${version}/bin/java" -version
}

# 安装 Oracle GraalVM JDK
# 参数: $1 - JDK 主版本号 (如 21, 25)
# 安装路径: /opt/graalvm-jdk-{version}
function install_graalvm_jdk() {
  local version=${1:?}
  local jdk_arch
  jdk_arch=$(detect_jdk_arch)

  echo ">>> Installing Oracle GraalVM JDK ${version} (arch: ${jdk_arch})..."

  # native-image 需要 C/C++ 编译器和开发头文件
  apt-get update
  apt-get install --no-install-recommends -y gcc g++ zlib1g-dev
  rm -rf /var/lib/apt/lists/*

  curl "https://download.oracle.com/graalvm/${version}/latest/graalvm-jdk-${version}_linux-${jdk_arch}_bin.tar.gz" -o /tmp/graalvm.tar.gz
  mkdir -p "/opt/graalvm-jdk-${version}"
  tar -xzf /tmp/graalvm.tar.gz --strip-components=1 -C "/opt/graalvm-jdk-${version}"
  rm -f /tmp/graalvm.tar.gz

  echo ">>> GraalVM JDK ${version} installed:"
  "/opt/graalvm-jdk-${version}/bin/java" -version
}

# 安装 Apache Maven
# 参数: $1 - Maven 版本号 (必填，由调用方脚本指定)
# 安装路径: /opt/maven
# 下载源: Maven 发行包同时发布到 Maven Central（内容不可变、历史版本永久保留），故优先取中央仓库；
#         官方 dlcdn 由 Fastly CDN 承载、速度最快，但只保留当前版本；archive.apache.org 作为完整归档兜底。
function install_maven() {
  local version=${1:?}

  echo ">>> Installing Apache Maven ${version}..."
  download_first_available /tmp/maven.tar.gz \
    "https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/${version}/apache-maven-${version}-bin.tar.gz" \
    "https://dlcdn.apache.org/maven/maven-3/${version}/binaries/apache-maven-${version}-bin.tar.gz" \
    "https://archive.apache.org/dist/maven/maven-3/${version}/binaries/apache-maven-${version}-bin.tar.gz"
  mkdir -p /opt/maven
  tar -xzf /tmp/maven.tar.gz --strip-components=1 -C /opt/maven
  rm -f /tmp/maven.tar.gz

  # 使用阿里云 Maven 镜像
  if [[ -f /tmp/settings.xml ]]; then
    cp /tmp/settings.xml /opt/maven/conf/settings.xml
  fi

  echo ">>> Maven ${version} installed:"
  /opt/maven/bin/mvn --version
}

# 安装 Apache JMeter
# 参数: $1 - JMeter 版本号 (必填，由调用方脚本指定)
# 安装路径: /opt/jmeter
# 下载源: JMeter 发行包未发布到 Maven Central，只能走 Apache 分发镜像；
#         官方 dlcdn 由 Fastly CDN 承载、速度最快但只保留当前版本，archive.apache.org 作为完整归档兜底。
function install_jmeter() {
  local version=${1:?}

  echo ">>> Installing Apache JMeter ${version}..."
  download_first_available /tmp/jmeter.tgz \
    "https://dlcdn.apache.org/jmeter/binaries/apache-jmeter-${version}.tgz" \
    "https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-${version}.tgz"
  mkdir -p /opt/jmeter
  tar -xzf /tmp/jmeter.tgz --strip-components=1 -C /opt/jmeter
  rm -f /tmp/jmeter.tgz

  echo ">>> JMeter ${version} installed:"
  /opt/jmeter/bin/jmeter --version
}

# 架构检测：将 uname -m 映射为 Godot 官方发行包的架构标识
function detect_godot_arch() {
  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64)  echo "x86_64" ;;
    aarch64) echo "arm64" ;;
    *) echo "ERROR: Unsupported architecture: $arch" >&2; exit 1 ;;
  esac
}

# 安装 Godot 编辑器（供 job 内的 headless 导入/导出复用，免去每次下载 78 MB）
# 参数: $1 - Godot 版本号 (如 4.7.2，对应上游 tag 4.7.2-stable)
# 安装路径: ${GODOT_HOME:-/opt/godot}/{version}/godot，并软链到 /usr/local/bin/godot
# 说明: 官方 Linux 编辑器二进制的 DT_NEEDED 只有 libc/libm/libdl/libpthread/librt，
#       X11/Wayland/Vulkan/ALSA/PulseAudio 均为 dlopen 加载，故 --headless 导出无需图形/音频库；
#       若要运行不带 --headless 的 Godot（真实渲染），需另行安装 libgl1 libx11-6 等运行库。
function install_godot_editor() {
  local version=${1:?}
  local godot_arch
  godot_arch=$(detect_godot_arch)
  local godot_home=${GODOT_HOME:-/opt/godot}

  echo ">>> Installing Godot ${version} editor (arch: ${godot_arch})..."
  curl "https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_linux.${godot_arch}.zip" -o /tmp/godot.zip
  rm -rf /tmp/godot-unpack
  unzip -q /tmp/godot.zip -d /tmp/godot-unpack
  mkdir -p "${godot_home}/${version}"
  mv "/tmp/godot-unpack/Godot_v${version}-stable_linux.${godot_arch}" "${godot_home}/${version}/godot"
  chmod +x "${godot_home}/${version}/godot"
  ln -sfn "${godot_home}/${version}/godot" /usr/local/bin/godot
  rm -rf /tmp/godot.zip /tmp/godot-unpack

  echo ">>> Godot ${version} installed:"
  godot --version
}

# 安装 Godot 导出模板（只保留 Web 与 Windows 桌面平台）
# 参数: $1 - Godot 版本号 (必填)
# 安装路径: ${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/.local/share/godot/export_templates}/{version}.stable
# 说明: 模板包 1.28 GiB（全平台），仅保留 Web 与全部 Windows 架构（32/64 位、arm64）后约 683 MiB；
#       目录名必须严格等于 {version}.stable，Godot 按该目录名查找模板。
function install_godot_export_templates() {
  local version=${1:?}
  local templates_root=${GODOT_EXPORT_TEMPLATES_DIR:-${HOME}/.local/share/godot/export_templates}

  echo ">>> Installing Godot ${version} export templates to ${templates_root}..."
  # 模板包 1.28 GiB，curl 封装里的 --max-time 300 会中途掐断，这里单独放宽到 30 分钟
  command curl -sSfL --connect-timeout 10 --max-time 1800 --retry 3 --retry-all-errors \
    "https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_export_templates.tpz" \
    -o /tmp/godot-templates.tpz
  rm -rf /tmp/godot-templates-unpack
  unzip -q /tmp/godot-templates.tpz -d /tmp/godot-templates-unpack
  mkdir -p "${templates_root}"
  rm -rf "${templates_root}/${version}.stable"
  mv /tmp/godot-templates-unpack/templates "${templates_root}/${version}.stable"
  rm -rf /tmp/godot-templates.tpz /tmp/godot-templates-unpack

  # 只保留 Web 与 Windows 桌面模板，其余平台（android/ios/macos/linux，约 600 MiB）删除以控制镜像体积；
  # icudt_godot.dat 是导出时可能用到的 ICU 数据（约 5 MiB），一并保留
  find "${templates_root}/${version}.stable" -maxdepth 1 -type f \
    ! -name 'version.txt' ! -name 'icudt_godot.dat' \
    ! -name 'web_*' ! -name 'windows_*' -delete

  echo ">>> Export templates installed:"
  ls -lh "${templates_root}/${version}.stable"
}
