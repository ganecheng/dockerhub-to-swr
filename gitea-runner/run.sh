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
# 导入自定义 CA 证书（若挂载目录存在证书文件）
# 系统侧：拷贝到 /usr/local/share/ca-certificates/ 后运行 update-ca-certificates
# Java 侧：通过 keytool 导入 JDK truststore（仅当 JAVA_HOME 可用时）
#################################################################
if [[ -d "${CA_CERT_DIR}" ]] && [[ -n "$(ls -A "${CA_CERT_DIR}" 2>/dev/null)" ]]; then
  log INFO "Importing CA certificates from ${CA_CERT_DIR} ..."
  counter=0
  for file in "${CA_CERT_DIR}"/*; do
    [[ -f "$file" ]] || continue
    counter=$((counter + 1))
    # 系统侧证书：拷贝到标准目录后由 update-ca-certificates 刷新证书束
    install -m 0644 "$file" "/usr/local/share/ca-certificates/ca-${counter}.crt"
    # Java 侧证书：导入 JDK truststore（基础镜像无 JAVA_HOME 时跳过）
    if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/keytool" ]]; then
      "${JAVA_HOME}/bin/keytool" -importcert \
        -alias "ca-${counter}" \
        -file "$file" \
        -keystore "${JAVA_HOME}/lib/security/cacerts" \
        -storepass changeit \
        -noprompt
    fi
  done
  update-ca-certificates
  log INFO "Imported ${counter} CA certificate(s)."
else
  log INFO "No CA certificates to import (directory ${CA_CERT_DIR} empty or missing)."
fi


#################################################################
# 配置 NPM 默认镜像仓库
#################################################################
npm config set registry "${NPM_REGISTRY}"
log INFO "NPM registry set to ${NPM_REGISTRY}"


#################################################################
# 启动 Docker 守护进程（直接后台启动）
#################################################################
log INFO "Starting Docker engine..."
# 清除可能残留的 PID 文件，避免 Docker 误认为已在运行
rm -f /var/run/docker.pid /run/docker/containerd/containerd.pid
# 配置 cgroup v2 嵌套、挂载 securityfs、设置共享挂载传播等容器内运行环境
/usr/local/bin/dind-hack true
# 后台启动 dockerd，由内核在容器销毁时回收
dockerd -p /var/run/docker.pid > /var/log/docker.log 2>&1 &
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
  # 固定为临时模式 (完成一个任务后自动退出，不可覆盖)
  log INFO "  Ephemeral mode enabled (runner will exit after completing one job)"
  register_args+=(--ephemeral)
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
# 保存超时配置（unset 后仍可使用），然后清除所有 GITEA_ 环境变量
#################################################################
runner_timeout_minutes=$GITEA_RUNNER_TIMEOUT_MINUTES
unset "${!GITEA_@}"

#################################################################
# 启动 Gitea Actions runner 守护进程
#################################################################
gitea-runner daemon --config "$effective_config_file" > /tmp/gitea-runner-daemon.log 2>&1 &
gitea_runner_pid=$!

# 计算超时时间戳（默认 60 分钟）
timeout_seconds=$((runner_timeout_minutes * 60))
start_time=$(date +%s)
deadline=$((start_time + timeout_seconds))
log INFO "Container timeout: ${runner_timeout_minutes}m (will exit after $(date -d "@$deadline" '+%H:%M:%S'))"

# 捕获退出信号：直接结束，容器销毁后内核自动回收子进程
trap "log INFO 'Received signal, exiting...'; exit 1" INT TERM HUP QUIT

# 主循环：等待 runner 完成/异常退出/超时
task_detected=false
while true; do
  # 检查 runner 是否存活
  if ! kill -0 "$gitea_runner_pid" 2>/dev/null; then
    log INFO "Gitea runner process exited."
    break
  fi

  # 检测 daemon 日志中是否出现任务接收标记（task N repo / Running job）
  # 仅第一次检测到时刷新超时 deadline，确保任务有充分的执行时间
  if [[ $task_detected == false ]] && grep -qiE "task [0-9]+ repo|Running job" /tmp/gitea-runner-daemon.log 2>/dev/null; then
    task_detected=true
    deadline=$(( $(date +%s) + timeout_seconds ))
    log INFO "Task received from server, timeout extended for task duration."
  fi

  # 检查超时
  now=$(date +%s)
  if [[ $now -ge $deadline ]]; then
    log INFO "Container idle timeout (${runner_timeout_minutes}m) reached, exiting."
    break
  fi
  sleep 60
done

log INFO "Container exiting, kernel will clean up all child processes."
exit 0