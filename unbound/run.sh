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
# 上游 DoT (DNS over TLS) 场景下用于校验上游服务器证书
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
# 生成 unbound 配置文件
# 通过环境变量配置 unbound 行为：
#   UNBOUND_PORT         - 监听端口（默认 53）
#   UNBOUND_ALLOWED_NETS - 允许查询的客户端网段，逗号分隔（默认 0.0.0.0/0）
#   UNBOUND_UPSTREAM     - 上游 DNS 服务器，逗号分隔（默认空 = 纯递归解析）
#   UNBOUND_FORWARD_TLS  - 设为 1 时上游使用 DoT，未带端口的上游默认补 @853（默认 0）
#   UNBOUND_CONF         - 自定义配置文件路径，设置后跳过自动生成（默认空）
#   UNBOUND_ARGS         - 额外的 unbound 命令行参数（如 -vvv 提高日志级别）
#################################################################
conf_file="${UNBOUND_CONF:-}"

if [[ -z "${conf_file}" ]]; then
  conf_file='/etc/unbound/unbound.conf'
  log INFO "Generating unbound configuration to ${conf_file} ..."

  {
    cat <<'CONF'
server:
    interface: 0.0.0.0
    do-ip4: yes
    do-ip6: yes
    do-udp: yes
    do-tcp: yes

    # 隐私与安全
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-below-nxdomain: yes
    qname-minimisation: yes

    # 缓存与预取
    prefetch: yes
    prefetch-key: yes

    # DNSSEC 根信任锚（RFC 5011）
    auto-trust-anchor-file: "/var/lib/unbound/root.key"

    # 日志输出到标准错误，便于 docker logs 查看
    verbosity: 1
    use-syslog: no
    logfile: ""

CONF
    printf '    port: %s\n' "${UNBOUND_PORT:-53}"

    # 默认拒绝所有查询，逐条放行允许的客户端网段
    IFS=',' read -r -a nets <<< "${UNBOUND_ALLOWED_NETS:-0.0.0.0/0}"
    for net in "${nets[@]}"; do
      net="$(printf '%s' "${net}" | tr -d '[:space:]')"
      [[ -n "${net}" ]] || continue
      printf '    access-control: %s allow\n' "${net}"
    done

    # 配置了上游 DNS 时生成 forward-zone（转发模式），否则为纯递归解析
    if [[ -n "${UNBOUND_UPSTREAM:-}" ]]; then
      printf '\nforward-zone:\n    name: "."\n'
      if [[ "${UNBOUND_FORWARD_TLS:-0}" == "1" ]]; then
        printf '    forward-tls-upstream: yes\n'
      fi
      IFS=',' read -r -a upstreams <<< "${UNBOUND_UPSTREAM}"
      for upstream in "${upstreams[@]}"; do
        upstream="$(printf '%s' "${upstream}" | tr -d '[:space:]')"
        [[ -n "${upstream}" ]] || continue
        if [[ "${UNBOUND_FORWARD_TLS:-0}" == "1" && "${upstream}" != *"@"* ]]; then
          upstream="${upstream}@853"
        fi
        printf '    forward-addr: %s\n' "${upstream}"
      done
    fi
  } > "${conf_file}"
fi

#################################################################
# 确保 DNSSEC 根信任锚文件存在
# 优先 unbound-anchor 联网引导，失败则回退到 dns-root-data 的静态根密钥
#################################################################
install -d -m 0755 -o unbound -g unbound /var/lib/unbound
if [[ ! -s /var/lib/unbound/root.key ]]; then
  if command -v unbound-anchor >/dev/null 2>&1 && unbound-anchor -a /var/lib/unbound/root.key; then
    log INFO "Bootstrapped DNSSEC root trust anchor via unbound-anchor."
  elif [[ -f /usr/share/dns/root.key ]]; then
    log WARN "unbound-anchor failed, falling back to static root key from dns-root-data."
    install -m 0644 /usr/share/dns/root.key /var/lib/unbound/root.key
  else
    log WARN "No DNSSEC root trust anchor available; unbound may fail to start."
  fi
fi
chown unbound:unbound /var/lib/unbound/root.key 2>/dev/null || true

#################################################################
# 校验配置文件（不合法则启动失败，便于及早暴露问题）
#################################################################
unbound-checkconf "${conf_file}"
log INFO "Configuration check passed: ${conf_file}"

# 打印最终生效的配置文件完整内容（自动生成或 UNBOUND_CONF 指定），便于通过 docker logs 排查
log INFO "Effective configuration (${conf_file}):"
log INFO < "${conf_file}"

# 额外命令行参数
unbound_args=(-d -c "${conf_file}")
if [[ -n "${UNBOUND_ARGS:-}" ]]; then
  read -r -a extra_args <<< "${UNBOUND_ARGS}"
  unbound_args+=("${extra_args[@]}")
fi

log INFO "Starting unbound on port ${UNBOUND_PORT:-53} ..."
exec unbound "${unbound_args[@]}"
