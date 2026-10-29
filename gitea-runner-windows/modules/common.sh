#!/usr/bin/env bash
# 共享安装函数库 (Git Bash 版)：Web 下载封装、Node.js/Qwen Code CLI/Gitea Runner/Flutter/7-Zip/Godot 安装
# 对应 Linux 版的 modules/common.sh
# VS Build Tools 和 NuGet 已由基础镜像 (windows) 提供，无需在此安装

set -exuo pipefail

# 封装 curl：统一超时和重试策略（与基础镜像 Dockerfile 一致）
function curl() {
  command curl -sSfL --connect-timeout 10 --max-time 300 --retry 3 --retry-all-errors "$@"
}

# 下载 Mozilla CA 证书包，供 Dart/Flutter TLS 验证使用
# Windows 容器根证书存储可能不完整，导致 Dart BoringSSL 验证失败 (CERTIFICATE_VERIFY_FAILED)
# 目标路径通过 SSL_CERT_FILE 环境变量指定 (由 Dockerfile.flutter ENV 设置)
function install_ca_certificates() {
  local cert_file=${SSL_CERT_FILE:-C:/opt/ssl/cacert.pem}
  local cert_dir
  cert_dir=$(dirname "$cert_file")

  echo ">>> Installing Mozilla CA certificates to $cert_file..."

  mkdir -p "$cert_dir"

  # 临时清除 SSL_CERT_FILE，避免 Git Bash 的 curl (OpenSSL) 尝试读取尚未下载的证书文件
  local saved_ssl_cert_file=${SSL_CERT_FILE:-}
  unset SSL_CERT_FILE
  curl "https://curl.se/ca/cacert.pem" -o "$cert_file"
  export SSL_CERT_FILE=$saved_ssl_cert_file

  # 验证下载的文件大小（Mozilla CA 包通常 > 200KB）
  local file_size
  file_size=$(wc -c < "$cert_file")
  if (( file_size < 100000 )); then
    echo "ERROR: cacert.pem download failed (size: ${file_size} bytes)" >&2
    exit 1
  fi

  echo ">>> CA certificates installed (${file_size} bytes)"
}

# 安装 Flutter SDK（仅启用 Windows 桌面构建）
# 参数: $1 - Flutter 版本号（必传，由 flutter.sh 从 ENV FLUTTER_VERSION 传入）
# 需要预先通过 Dockerfile ENV 设置 FLUTTER_VERSION、FLUTTER_ROOT 和 PATH
function install_flutter() {
  local version=${1:?}
  # Docker ENV 设置的是进程级环境变量，优先读取
  local flutter_root=${FLUTTER_ROOT:-C:/flutter}

  echo ">>> Installing Flutter $version to $flutter_root..."

  # 路径以正斜杠形式提供给 Windows 原生 git.exe，避免 bash 反斜杠转义陷阱；
  # Git Bash 会自动将 C:/... 路径作为 Windows 路径传递给 git.exe。
  git clone --depth 1 --branch "$version" https://github.com/flutter/flutter.git "$flutter_root"
  git config --global --add safe.directory "$flutter_root"

  flutter --version
  dart --disable-analytics
  flutter config --no-cli-animations --no-analytics \
    --no-enable-android --no-enable-web --no-enable-linux-desktop \
    --enable-windows-desktop --no-enable-fuchsia --no-enable-custom-devices \
    --no-enable-ios --no-enable-macos-desktop
  flutter precache --windows

  # 清理示例和开发文档（节省 ~200MB）
  rm -rf \
    "$flutter_root/examples" \
    "$flutter_root/dev"

  flutter doctor -v
  echo ">>> Flutter $version installed"
}

# 安装 Node.js（GitHub Actions 运行时依赖）
# 参数: $1 - Node.js 版本号（必传，由 setup.sh 从 ENV NODE_VERSION 传入）
# 安装路径: 通过 NODE_HOME 环境变量指定 (默认 C:/Program Files/nodejs)
function install_node() {
  local version=${1:?}
  local arch
  arch=$(uname -m)
  local node_arch
  case "$arch" in
    x86_64|amd64)  node_arch="x64" ;;
    aarch64|arm64) node_arch="arm64" ;;
    *) echo "ERROR: Unsupported architecture: $arch" >&2; exit 1 ;;
  esac

  local node_home=${NODE_HOME:-C:/Program Files/nodejs}
  local tmp_dir=C:/tmp/node-install

  echo ">>> Installing Node.js $version ($node_arch) to $node_home..."

  mkdir -p "$tmp_dir"
  curl "https://nodejs.org/dist/v${version}/node-v${version}-win-${node_arch}.zip" -o "$tmp_dir/node.zip"

  # 使用 PowerShell 解压 zip（Git Bash 自带的 GNU tar 不支持 zip 格式）
  pwsh -NoProfile -Command "Expand-Archive -Path '$tmp_dir/node.zip' -DestinationPath '$tmp_dir/extracted' -Force"

  mkdir -p "$node_home"
  cp -r "$tmp_dir/extracted/node-v${version}-win-${node_arch}/"* "$node_home/"
  rm -rf "$tmp_dir"

  echo ">>> Node.js $version installed:"
  "$node_home/node.exe" --version
  "$node_home/npm.cmd" --version
}

# 安装 Qwen Code CLI（npm 全局安装）
# 参数: $1 - Qwen Code 版本号（必传，由 setup.sh 从 ENV QWEN_CODE_VERSION 传入）
# 全局安装目录: 通过 NPM_GLOBAL_HOME 环境变量指定 (默认 C:/opt/npm)
function install_qwen_code() {
  local version=${1:?}
  local node_home=${NODE_HOME:-C:/Program Files/nodejs}
  local npm_global_home=${NPM_GLOBAL_HOME:-C:/opt/npm}

  echo ">>> Installing Qwen Code $version to $npm_global_home..."

  # npm 在 Windows 的默认全局前缀为 %APPDATA%\npm（不在 PATH 中），显式指定前缀以便 qwen 可直接调用
  NPM_CONFIG_PREFIX="$npm_global_home" "$node_home/npm.cmd" install -g "@qwen-code/qwen-code@${version}"

  echo ">>> Qwen Code $version installed:"
  "$npm_global_home/qwen.cmd" --version
}

# 安装 Gitea Runner
# 参数: $1 - Gitea Runner 版本号（必传，由 setup.sh 从 ENV GITEA_RUNNER_VERSION 传入）
# 安装路径: 通过 GITEA_RUNNER_HOME 环境变量指定 (默认 C:/opt/bin)
function install_gitea_runner() {
  local version=${1:?}
  local arch
  arch=$(uname -m)
  local runner_arch
  case "$arch" in
    x86_64|amd64)  runner_arch="amd64" ;;
    aarch64|arm64) runner_arch="arm64" ;;
    *) echo "ERROR: Unsupported architecture: $arch" >&2; exit 1 ;;
  esac

  local runner_home=${GITEA_RUNNER_HOME:-C:/opt/bin}

  echo ">>> Installing Gitea Runner $version ($runner_arch) to $runner_home..."

  mkdir -p "$runner_home"
  curl "https://gitea.com/gitea/runner/releases/download/v${version}/gitea-runner-${version}-windows-${runner_arch}.exe" -o "$runner_home/gitea-runner.exe"

  echo ">>> Gitea Runner $version installed:"
  "$runner_home/gitea-runner.exe" --version
}

# 安装 7-Zip（job 内的 "7z x" 依赖它；Git Bash 里不带 .exe 也能直接调用）
# 安装目录 C:\Program Files\7-Zip 由 Dockerfile.godot 追加到机器级 PATH，
# 这里同时 export 到当前进程，供后续安装步骤（解压 Godot/tpz）直接使用。
function install_7zip() {
  local seven_zip_home="C:/Program Files/7-Zip"

  echo ">>> Installing 7-Zip..."
  choco install 7zip -y --no-progress
  export PATH="$PATH:$seven_zip_home"

  local seven_zip_exe="$seven_zip_home/7z.exe"
  if [[ ! -x "$seven_zip_exe" ]]; then
    # chocolatey 若改用 shim 方式安装，7z 会落在 chocolatey\bin 下
    seven_zip_exe=$(command -v 7z || true)
  fi
  if [[ -z "$seven_zip_exe" || ! -x "$seven_zip_exe" ]]; then
    echo "ERROR: 7z.exe not found after choco install" >&2
    exit 1
  fi

  echo ">>> 7-Zip installed:"
  # 用 "7z i" 打印版本信息（无参数直接调用在 set -o pipefail 下不够稳妥）
  "$seven_zip_exe" i | sed -n '1,2p'
}

# 安装 Godot 编辑器（Windows 桌面版，供 job 内的 headless 导入/导出复用）
# 参数: $1 - Godot 版本号 (如 4.7.2，对应上游 tag 4.7.2-stable)
# 安装路径: ${GODOT_HOME:-C:/opt/godot}，并在 ${GITEA_RUNNER_HOME:-C:/opt/bin} 生成 godot 包装脚本
# 说明: _console.exe 是主程序的包装器，两者必须在同一目录并保持 "_console" 命名对应关系，
#       因此保留官方文件名，另用包装脚本提供与 Linux 版一致的 godot 命令。
function install_godot_editor() {
  local version=${1:?}
  local godot_home=${GODOT_HOME:-C:/opt/godot}
  godot_home=${godot_home//\\//}
  local bin_dir=${GITEA_RUNNER_HOME:-C:/opt/bin}
  bin_dir=${bin_dir//\\//}
  local tmp_dir=C:/tmp/godot-install

  echo ">>> Installing Godot ${version} editor (win64) to ${godot_home}..."
  mkdir -p "$tmp_dir" "$godot_home"
  curl "https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_win64.exe.zip" -o "$tmp_dir/godot.zip"
  7z x -y "$tmp_dir/godot.zip" -o"$godot_home" > /dev/null
  rm -rf "$tmp_dir"

  mkdir -p "$bin_dir"
  cat > "$bin_dir/godot" <<EOF
#!/usr/bin/env bash
exec "${godot_home}/Godot_v${version}-stable_win64_console.exe" "\$@"
EOF
  chmod +x "$bin_dir/godot"

  echo ">>> Godot ${version} installed:"
  "$bin_dir/godot" --version
}

# 安装 Godot 导出模板（只保留 Web 与 Windows 桌面平台）
# 参数: $1 - Godot 版本号 (必填)
# 安装路径: ${GODOT_EXPORT_TEMPLATES_DIR:-%APPDATA%\Godot\export_templates}\{version}.stable
# 说明: 模板包 1.28 GiB（全平台），仅保留 Web 与全部 Windows 架构（32/64 位、arm64）后约 683 MiB；
#       目录名必须严格等于 {version}.stable，Godot 按该目录名查找模板。
function install_godot_export_templates() {
  local version=${1:?}
  local templates_root=${GODOT_EXPORT_TEMPLATES_DIR:-${APPDATA:-C:/Users/ContainerAdministrator/AppData/Roaming}/Godot/export_templates}
  # APPDATA 是 Windows 反斜杠形式，转成正斜杠后才能被 Git Bash 的文件工具正确解析
  templates_root=${templates_root//\\//}
  local tmp_dir=C:/tmp/godot-install

  echo ">>> Installing Godot ${version} export templates to ${templates_root}..."
  mkdir -p "$tmp_dir"
  # 模板包 1.28 GiB，curl 封装里的 --max-time 300 会中途掐断，这里单独放宽到 30 分钟
  command curl -sSfL --connect-timeout 10 --max-time 1800 --retry 3 --retry-all-errors \
    "https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_export_templates.tpz" \
    -o "$tmp_dir/templates.tpz"
  7z x -y "$tmp_dir/templates.tpz" -o"$tmp_dir/unpacked" > /dev/null
  mkdir -p "$templates_root"
  rm -rf "$templates_root/${version}.stable"
  mv "$tmp_dir/unpacked/templates" "$templates_root/${version}.stable"
  rm -rf "$tmp_dir"

  # 只保留 Web 与 Windows 桌面模板，其余平台（android/ios/macos/linux，约 600 MiB）删除以控制镜像体积；
  # icudt_godot.dat 是导出时可能用到的 ICU 数据（约 5 MiB），一并保留
  find "$templates_root/${version}.stable" -maxdepth 1 -type f \
    ! -name 'version.txt' ! -name 'icudt_godot.dat' \
    ! -name 'web_*' ! -name 'windows_*' -delete

  echo ">>> Export templates installed:"
  ls -lh "$templates_root/${version}.stable"
}