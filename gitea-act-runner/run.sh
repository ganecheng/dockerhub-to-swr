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
if [[ ${1:-} == "" ]]; then
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
  env | grep '^GITEA_\|^ACT_' | sort | sed -E 's/^([^=]*(TOKEN|SECRET|PASSWORD)[^=]*=).*/\1******/I' | sed -e 's/^/ - /'
fi


#################################################################
# 启动 Docker 守护进程
#################################################################
log INFO "Starting Docker engine..."
# 清除可能残留的 PID 文件，避免 Docker 误认为已在运行
rm -f /var/run/docker.pid /run/docker/containerd/containerd.pid
/usr/local/bin/dind-hack true
service docker start
# 轮询等待 Docker 引擎就绪
while ! docker stats --no-stream &>/dev/null; do
  log INFO "Waiting for Docker engine to start..."
  sleep 2
  tail -n 1 /var/log/docker.log
done
export DOCKER_PID=$(</var/run/docker.pid)
echo "==========================================================="
docker info
echo "==========================================================="

# 若未显式指定 Job 容器的 Docker 主机地址，则回退到默认 socket
if [[ -z ${GITEA_RUNNER_JOB_CONTAINER_DOCKER_HOST:-} ]]; then
  export GITEA_RUNNER_JOB_CONTAINER_DOCKER_HOST=${DOCKER_HOST:-unix:///var/run/docker.sock}
fi

# 启动 Gitea Act Runner 主进程
exec bash /opt/run_runner.sh
