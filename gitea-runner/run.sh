#!/usr/bin/env bash

set -euo pipefail

# 日志函数：统一输出格式，支持带级别的前缀
function log() {
  local level=${1:-INFO}
  level=${level^^}  # 转为大写
  shift
  local prefix
  prefix="$(date "+%Y-%m-%d %H:%M:%S") $level"
  if (( $# )); then
    # 有参数时直接输出
    printf '%s %s\n' "$prefix" "$*"
  else
    # 无参数时从标准输入逐行读取（用于管道场景）
    while IFS= read -r line; do
      printf '%s %s\n' "$prefix" "$line"
    done
  fi
}

#################################################################
# 打印启动横幅和环境信息
#################################################################
if [[ $# -eq 0 ]]; then
  cat <<'EOF'
   _____ _ _               _____
  / ____(_) |             |  __ \
 | |  __ _| |_ ___  __ _  | |__) |   _ _ __  _ __   ___ _ __
 | | |_ | | __/ _ \/ _` | |  _  / | | | '_ \| '_ \ / _ \ '__|
 | |__| | | ||  __/ (_| | | | \ \ |_| | | | | | | |  __/ |
  \_____|_|\__\___|\__,_| |_|  \_\__,_|_| |_|_| |_|\___|_|
EOF

  echo

  log INFO "$(gitea-runner --version)"
  log INFO "Timezone: $(date +"%Z %z")"
  log INFO "Hostname: $(hostname -f)"
  log INFO "IP Addresses: "
  # 从 /proc/net/fib_trie 提取本机 IP 地址，过滤回环地址
  awk '/32 host/ { if(uniq[ip]++ && ip != "127.0.0.1") print " - " ip } {ip=$2}' /proc/net/fib_trie
  log INFO "Config environment variables: "
  # 输出 GITEA_/ACT_ 开头的环境变量，对敏感信息（TOKEN/SECRET/PASSWORD）脱敏
  env | grep '^GITEA_\|^ACT_' | sort | sed -E 's/^([^=]*(TOKEN|SECRET|PASSWORD)[^=]*=).*/\1******/I; s/^/ - /'
fi


#################################################################
# 启动 Docker 守护进程
#################################################################
log INFO "Starting Docker engine..."
# 清除可能残留的 PID 文件，避免 Docker 误认为已在运行
rm -f /var/run/docker.pid /run/docker/containerd/containerd.pid
/usr/local/bin/dind-hack true
dockerd > /var/log/docker.log 2>&1 &
DOCKER_PID=$!
# 轮询等待 Docker 引擎就绪
while ! docker stats --no-stream &>/dev/null; do
  log INFO "Waiting for Docker engine to start..."
  sleep 2
  tail -n 1 /var/log/docker.log
done
echo "==========================================================="
docker info
echo "==========================================================="

# 若未显式指定 Job 容器的 Docker 主机地址，则回退到默认 socket
if [[ -z ${GITEA_RUNNER_JOB_CONTAINER_DOCKER_HOST:-} ]]; then
  export GITEA_RUNNER_JOB_CONTAINER_DOCKER_HOST=${DOCKER_HOST:-unix:///var/run/docker.sock}
fi


#################################################################
# 启动 Gitea Act Runner 主进程
#################################################################
log INFO "Effective user: $(id)"

# 切换到数据目录 (runner 的工作目录)
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
# 若未指定 runner 标签, 则使用默认标签
if [[ -z ${GITEA_RUNNER_LABELS:-} ]]; then
  GITEA_RUNNER_LABELS=$GITEA_RUNNER_LABELS_DEFAULT
fi

effective_config_file=/tmp/gitea_runner_config.yml
rm -f "$effective_config_file"
# 逐行读取模板, 用 eval 进行变量展开后写入配置文件
while IFS= read -r line; do
  line=${line//\"/\\\"}
  line=${line//\`/\\\`}
  eval "echo \"$line\"" >> "$effective_config_file"
done < "$GITEA_RUNNER_CONFIG_TEMPLATE_FILE"

#################################################################
# 注册 runner (若未注册过则向 Gitea 实例注册)
#################################################################
if [[ ! -s ${GITEA_RUNNER_REGISTRATION_FILE:-.runner} ]]; then
  # 未直接提供 token 时, 从文件读取
  if [[ -z ${GITEA_RUNNER_REGISTRATION_TOKEN:-} ]]; then
    read -r GITEA_RUNNER_REGISTRATION_TOKEN < "$GITEA_RUNNER_REGISTRATION_TOKEN_FILE"
  fi

  log INFO "Trying to register runner with Gitea..."
  log INFO "  GITEA_INSTANCE_URL=$GITEA_INSTANCE_URL"
  log INFO "  GITEA_RUNNER_NAME=$GITEA_RUNNER_NAME"
  log INFO "  GITEA_RUNNER_REGISTRATION_TOKEN=${GITEA_RUNNER_REGISTRATION_TOKEN//?/*}"  # token 用星号遮掩
  log INFO "  GITEA_RUNNER_LABELS=$GITEA_RUNNER_LABELS"
  # 构建注册参数 (循环内不变, 移出避免重复构建)
  register_args=(
    --instance "$GITEA_INSTANCE_URL"
    --token    "$GITEA_RUNNER_REGISTRATION_TOKEN"
    --name     "$GITEA_RUNNER_NAME"
    --labels   "$GITEA_RUNNER_LABELS"
    --config   "$effective_config_file"
    --no-interactive
  )
  # 判断是否为临时模式 (完成一个任务后自动退出)
  if [[ $GITEA_RUNNER_EPHEMERAL == "true" || $GITEA_RUNNER_EPHEMERAL == "1" ]]; then
    log INFO "  GITEA_RUNNER_EPHEMERAL=$GITEA_RUNNER_EPHEMERAL (runner will exit after completing one job)"
    register_args+=(--ephemeral)
  fi
  # 带超时的重试注册循环
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

# 优雅停止 runner
function shutdown_act() {
  log INFO "Stopping gitea-runner..."
  (set -x; kill -SIGTERM "$gitea_runner_pid" || true)
}

# 优雅停止 Docker 引擎并等待其退出
function shutdown_docker() {
  log INFO "Stopping docker engine..."
  (set -x; kill "$DOCKER_PID" || true)
  while [[ -e /proc/$DOCKER_PID ]]; do
    log INFO "Waiting for docker engine to shutdown..."
    sleep 2
  done
}

# 捕获退出信号: 先停 runner 再停 Docker
trap "shutdown_act; shutdown_docker" INT TERM HUP QUIT

# 等待 Docker 引擎或 runner 任一进程退出
while [[ -e /proc/$DOCKER_PID && -e /proc/$gitea_runner_pid ]]; do
  sleep 1
done

# 若 runner 先退出而 Docker 仍在运行, 则停止 Docker; 反之亦然
if [[ -e /proc/$DOCKER_PID ]]; then
  shutdown_docker
else
  log ERROR "Docker engine unexpectly ended."
  shutdown_act
fi
exit 1
