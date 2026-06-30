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

function is_truthy() {
  [[ ${1:-} == "true" || ${1:-} == "1" || ${1:-} == "yes" ]]
}

#################################################################
# 打印启动横幅和环境信息
#################################################################
if [[ $# -eq 0 ]]; then
  cat <<'EOF'
   _____ _ _               _____                              _  _______     
  / ____(_) |             |  __ \                            | |/ / ____|    
 | |  __ _| |_ ___  __ _  | |__) |   _ _ __  _ __   ___ _ __ | ' / (___      
 | | |_ | | __/ _ \/ _` | |  _  / | | | '_ \| '_ \ / _ \ '__||  < \___ \     
 | |__| | | ||  __/ (_| | | | \ \ |_| | | | | | | |  __/ |   | . \____) |    
  \_____|_|\__\___|\__,_| |_|  \_\__,_|_| |_|_| |_|\___|_|   |_|\_\_____/    
EOF

  echo

  log INFO "$(gitea-runner --version)"
  log INFO "$(k3s --version | head -n 1)"
  log INFO "Timezone: $(date +"%Z %z")"
  log INFO "Hostname: $(hostname -f)"
  log INFO "IP Addresses: "
  awk '/32 host/ { if(uniq[ip]++ && ip != "127.0.0.1") print " - " ip } {ip=$2}' /proc/net/fib_trie
  log INFO "Config environment variables: "
  env | grep '^GITEA_\|^ACT_\|^K3S_' | sort | sed -E 's/^([^=]*(TOKEN|SECRET|PASSWORD)[^=]*=).*/\1******/I; s/^/ - /'
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
docker info
echo "==========================================================="

if [[ -z ${GITEA_RUNNER_JOB_CONTAINER_DOCKER_HOST:-} ]]; then
  export GITEA_RUNNER_JOB_CONTAINER_DOCKER_HOST=${DOCKER_HOST:-unix:///var/run/docker.sock}
fi

#################################################################
# 启动 k3s 单节点集群
#################################################################
k3s_pid=''
if is_truthy "${K3S_ENABLED:-true}"; then
  log INFO "Starting k3s server..."
  install -d /etc/rancher/k3s /var/lib/rancher/k3s
  rm -f /run/k3s/containerd/containerd.pid
  k3s_runtime_args=()
  if is_truthy "${K3S_USE_DOCKER:-true}"; then
    k3s_runtime_args+=(--docker)
  fi
  read -r -a k3s_extra_args <<< "${K3S_EXTRA_ARGS:-}"
  k3s server \
    --write-kubeconfig "${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}" \
    --write-kubeconfig-mode "${K3S_KUBECONFIG_MODE:-644}" \
    "${k3s_runtime_args[@]}" \
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
else
  log INFO "K3S_ENABLED=$K3S_ENABLED, skipping k3s startup."
fi

#################################################################
# 启动 Gitea Act Runner 主进程
#################################################################
log INFO "Effective user: $(id)"

cd /data || exit 1

#################################################################
# 加载自定义初始化脚本 (如指定了 INIT_SH_FILE)
#################################################################
if [[ -f "$INIT_SH_FILE" ]]; then
  log INFO "Loading [$INIT_SH_FILE]..."
  source "$INIT_SH_FILE"
fi

#################################################################
# 从模板渲染配置文件 (用环境变量替换模板中的占位符)
#################################################################
if [[ -z ${GITEA_RUNNER_LABELS:-} ]]; then
  GITEA_RUNNER_LABELS=$GITEA_RUNNER_LABELS_DEFAULT
fi

effective_config_file=/tmp/gitea_runner_config.yml
rm -f "$effective_config_file"
while IFS= read -r line; do
  line=${line//\"/\\\"}
  line=${line//\`/\\\`}
  eval "echo \"$line\"" >> "$effective_config_file"
done < "$GITEA_RUNNER_CONFIG_TEMPLATE_FILE"

#################################################################
# 注册 runner (若未注册过则向 Gitea 实例注册)
#################################################################
if [[ ! -s ${GITEA_RUNNER_REGISTRATION_FILE:-.runner} ]]; then
  if [[ -z ${GITEA_RUNNER_REGISTRATION_TOKEN:-} ]]; then
    read -r GITEA_RUNNER_REGISTRATION_TOKEN < "$GITEA_RUNNER_REGISTRATION_TOKEN_FILE"
  fi

  log INFO "Trying to register runner with Gitea..."
  log INFO "  GITEA_INSTANCE_URL=$GITEA_INSTANCE_URL"
  log INFO "  GITEA_RUNNER_NAME=$GITEA_RUNNER_NAME"
  log INFO "  GITEA_RUNNER_REGISTRATION_TOKEN=${GITEA_RUNNER_REGISTRATION_TOKEN//?/*}"
  log INFO "  GITEA_RUNNER_LABELS=$GITEA_RUNNER_LABELS"
  register_args=(
    --instance "$GITEA_INSTANCE_URL"
    --token    "$GITEA_RUNNER_REGISTRATION_TOKEN"
    --name     "$GITEA_RUNNER_NAME"
    --labels   "$GITEA_RUNNER_LABELS"
    --config   "$effective_config_file"
    --no-interactive
  )
  if [[ $GITEA_RUNNER_EPHEMERAL == "true" || $GITEA_RUNNER_EPHEMERAL == "1" ]]; then
    log INFO "  GITEA_RUNNER_EPHEMERAL=$GITEA_RUNNER_EPHEMERAL (runner will exit after completing one job)"
    register_args+=(--ephemeral)
  fi
  wait_until=$(( $(date +%s) + GITEA_RUNNER_REGISTRATION_TIMEOUT ))
  while true; do
    if gitea-runner register "${register_args[@]}"; then
      break
    fi
    if [ "$(date +%s)" -ge $wait_until ]; then
      log ERROR "Runner registration failed."
      exit 1
    fi
    sleep "$GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL"
  done
fi

#################################################################
# 清除所有 GITEA_ 开头的环境变量, 避免触发弃用警告
#################################################################
unset "${!GITEA_@}"

#################################################################
# 启动 Gitea Actions runner 守护进程并等待退出
#################################################################
gitea-runner daemon --config "$effective_config_file" &
gitea_runner_pid=$!

function shutdown_act() {
  log INFO "Stopping gitea-runner..."
  (set -x; kill -SIGTERM "$gitea_runner_pid" || true)
}

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

trap "shutdown_act; shutdown_k3s; shutdown_docker" INT TERM HUP QUIT

while [[ -e /proc/$DOCKER_PID && -e /proc/$gitea_runner_pid ]]; do
  if [[ -n $k3s_pid && ! -e /proc/$k3s_pid ]]; then
    log ERROR "k3s server unexpectly ended."
    shutdown_act
    shutdown_docker
    exit 1
  fi
  sleep 1
done

if [[ -e /proc/$DOCKER_PID ]]; then
  shutdown_act
  shutdown_k3s
  shutdown_docker
else
  log ERROR "Docker engine unexpectly ended."
  shutdown_act
  shutdown_k3s
fi
exit 1
