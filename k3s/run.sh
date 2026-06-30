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
# 加载自定义初始化脚本 (如指定了 INIT_SH_FILE)
#################################################################
if [[ -f "$INIT_SH_FILE" ]]; then
  log INFO "Loading [$INIT_SH_FILE]..."
  source "$INIT_SH_FILE"
fi

#################################################################
# 打印启动横幅和环境信息
#################################################################
if [[ $# -eq 0 ]]; then
  cat <<'EOF'
  _    _____
 | | _|___ / ___
 | |/ / |_ \/ __|
 |   < ___) \__ \
 |_|\_\____/|___/
EOF

  echo

  log INFO "$(docker --version)"
  log INFO "$(k3s --version | head -n 1)"
  log INFO "Timezone: $(date +"%Z %z")"
  log INFO "Hostname: $(hostname -f)"
  log INFO "IP Addresses: "
  awk '/32 host/ { if(uniq[ip]++ && ip != "127.0.0.1") print " - " ip } {ip=$2}' /proc/net/fib_trie
  log INFO "Config environment variables: "
  env | grep '^DOCKER_\|^K3S_\|^KUBECONFIG=\|^INIT_SH_FILE=' | sort | sed -E 's/^([^=]*(TOKEN|SECRET|PASSWORD)[^=]*=).*/\1******/I; s/^/ - /'
fi

#################################################################
# 启动 Docker 守护进程
#################################################################
log INFO "Starting Docker engine..."
rm -f /var/run/docker.pid /run/docker/containerd/containerd.pid
/usr/local/bin/dind-hack true
service docker start
while ! docker stats --no-stream &>/dev/null; do
  log INFO "Waiting for Docker engine to start..."
  sleep 2
  tail -n 1 /var/log/docker.log
done
export DOCKER_PID=$(</var/run/docker.pid)
echo "==========================================================="
docker version
echo "==========================================================="

#################################################################
# 准备 k3s airgap 镜像
#################################################################
install -d /var/lib/rancher/k3s/agent/images
if [[ -f /opt/k3s/k3s-airgap-images.tar.zst ]]; then
  log INFO "Restoring k3s airgap images to rancher data directory..."
  cp /opt/k3s/k3s-airgap-images.tar.zst /var/lib/rancher/k3s/agent/images/
  log INFO "Loading k3s airgap images into Docker..."
  zstd -dc /opt/k3s/k3s-airgap-images.tar.zst | docker load
fi

#################################################################
# 启动 k3s 单节点集群
#################################################################
k3s_pid=''
log INFO "Starting k3s server..."
install -d /etc/rancher/k3s /var/lib/rancher/k3s
rm -f /run/k3s/containerd/containerd.pid
read -r -a k3s_extra_args <<< "${K3S_EXTRA_ARGS:-}"
k3s server \
  --write-kubeconfig "${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}" \
  --write-kubeconfig-mode "${K3S_KUBECONFIG_MODE:-644}" \
  --docker \
  "${k3s_extra_args[@]}" &
k3s_pid=$!

wait_until=$(( $(date +%s) + ${K3S_STARTUP_TIMEOUT:-120} ))
while ! kubectl get nodes &>/dev/null; do
  if ! [[ -e /proc/$k3s_pid ]]; then
    log ERROR "k3s server exited before becoming ready."
    exit 1
  fi
  if [[ $(date +%s) -ge $wait_until ]]; then
    log ERROR "Timed out waiting for k3s server to become ready."
    exit 1
  fi
  log INFO "Waiting for k3s server to start..."
  sleep 2
done
kubectl get nodes -o wide

function shutdown_k3s() {
  if [[ -n $k3s_pid && -e /proc/$k3s_pid ]]; then
    log INFO "Stopping k3s server..."
    (set -x; kill -SIGTERM "$k3s_pid" || true)
    while [[ -e /proc/$k3s_pid ]]; do
      log INFO "Waiting for k3s server to shutdown..."
      sleep 2
    done
  fi
}

function shutdown_docker() {
  log INFO "Stopping docker engine..."
  (set -x; service docker stop)
  while [[ -e /proc/$DOCKER_PID ]]; do
    log INFO "Waiting for docker engine to shutdown..."
    sleep 2
  done
}

function shutdown_all() {
  shutdown_k3s
  shutdown_docker
}

trap "shutdown_all; exit 0" INT TERM HUP QUIT

if [[ -n $k3s_pid ]]; then
  while [[ -e /proc/$DOCKER_PID && -e /proc/$k3s_pid ]]; do
    sleep 1
  done

  if [[ ! -e /proc/$k3s_pid ]]; then
    log ERROR "k3s server unexpectedly ended."
    shutdown_docker
  else
    log ERROR "Docker engine unexpectedly ended."
    shutdown_k3s
  fi
else
  while [[ -e /proc/$DOCKER_PID ]]; do
    sleep 1
  done
  log ERROR "Docker engine unexpectedly ended."
fi

exit 1
