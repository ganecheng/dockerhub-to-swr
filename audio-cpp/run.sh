#!/usr/bin/env bash
set -euo pipefail

# 日志函数：统一输出格式，支持带级别的前缀
function log() {
  local level=${1:-INFO}
  level=${level^^}
  shift
  local prefix
  prefix="$(date "+%Y-%m-%d %H:%M:%S") $level"
  if (( $# )); then
    printf '%s %s\n' "$prefix" "$*"
  else
    while IFS= read -r line; do
      printf '%s %s\n' "$prefix" "$line"
    done
  fi
}

#################################################################
# 导入自定义 CA 证书（若挂载目录存在证书文件）
# 系统侧：拷贝到 /usr/local/share/ca-certificates/ 后运行 update-ca-certificates
#################################################################
if [[ -d "${CA_CERT_DIR}" ]] && [[ -n "$(ls -A "${CA_CERT_DIR}" 2>/dev/null)" ]]; then
  log INFO "Importing CA certificates from ${CA_CERT_DIR} ..."
  counter=0
  for file in "${CA_CERT_DIR}"/*; do
    [[ -f "$file" ]] || continue
    counter=$((counter + 1))
    install -m 0644 "$file" "/usr/local/share/ca-certificates/ca-${counter}.crt"
  done
  update-ca-certificates
  log INFO "Imported ${counter} CA certificate(s)."
else
  log INFO "No CA certificates to import (directory ${CA_CERT_DIR} empty or missing)."
fi

#################################################################
# 启动 audio.cpp
# 通过环境变量配置行为：
#   AUDIO_CPP_COMMAND - 要运行的命令（cli / server / gguf，默认 server）
#   AUDIO_CPP_ARGS    - 额外参数（如 --port 8080 --model /app/models/whisper.bin）
#################################################################
case "${AUDIO_CPP_COMMAND}" in
  cli)    binary="audiocpp_cli" ;;
  server) binary="audiocpp_server" ;;
  gguf)   binary="audiocpp_gguf" ;;
  *)
    log ERROR "Unknown command: ${AUDIO_CPP_COMMAND}"
    log INFO "Available commands: cli, server, gguf"
    exit 1
    ;;
esac

read -r -a extra_args <<< "${AUDIO_CPP_ARGS:-}"

log INFO "Starting ${binary} ..."
exec "./${binary}" "${extra_args[@]}"
