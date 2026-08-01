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
# 启动 ttyd
# 通过环境变量配置 ttyd 行为：
#   TTYD_PORT       - 监听端口（默认 7681）
#   TTYD_CREDENTIAL - Basic 认证凭据（格式 username:password，默认无认证）
#   TTYD_WRITABLE   - 设为 1 允许客户端写入终端（默认只读）
#   TTYD_COMMAND    - 终端中执行的命令（默认 bash）
#   TTYD_ARGS       - 额外的 ttyd 参数（如 -m 2 -O 等）
#################################################################
ttyd_opts=(-p "${TTYD_PORT}")

if [[ -n "${TTYD_CREDENTIAL:-}" ]]; then
  ttyd_opts+=(-c "${TTYD_CREDENTIAL}")
fi

if [[ "${TTYD_WRITABLE:-0}" == "1" ]]; then
  ttyd_opts+=(-W)
fi

if [[ -n "${TTYD_ARGS:-}" ]]; then
  read -r -a extra_args <<< "${TTYD_ARGS}"
  ttyd_opts+=("${extra_args[@]}")
fi

read -r -a command_args <<< "${TTYD_COMMAND}"

log INFO "Starting ttyd on port ${TTYD_PORT} ..."
exec ttyd "${ttyd_opts[@]}" "${command_args[@]}"
