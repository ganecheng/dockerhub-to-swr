#!/usr/bin/env bash

# -e: 出错即退出  -u: 未定义变量报错  -o pipefail: 管道中任一命令失败即整体失败
set -euo pipefail

# 日志函数: 输出带时间戳和级别的日志, 支持参数和管道输入
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

log INFO "Effective user: $(id)"

# 切换到数据目录 (runner 的工作目录)
cd /data || exit 1


#################################################
# 加载自定义初始化脚本 (如指定了 INIT_SH_FILE)
#################################################
if [[ -f "$INIT_SH_FILE" ]]; then
  log INFO "Loading [$INIT_SH_FILE]..."
  source "$INIT_SH_FILE"
fi


#################################################
# 从模板渲染配置文件 (用环境变量替换模板中的占位符)
#################################################
# 若未指定 runner 标签, 则使用默认标签
if [[ -z ${GITEA_RUNNER_LABELS:-} ]]; then
  GITEA_RUNNER_LABELS=$GITEA_RUNNER_LABELS_DEFAULT
fi

effective_config_file=/tmp/gitea_runner_config.yml
rm -f "$effective_config_file"
if [[ ${GITEA_RUNNER_LOG_EFFECTIVE_CONFIG:-false} == "true" ]]; then
  log INFO "Effective runner config [$effective_config_file]:"
  echo "==========================================================="
  # 逐行读取模板, 用 eval 进行变量展开后写入配置文件 (同时打印到控制台)
  while IFS= read -r line; do
    line=${line//\"/\\\"}
    line=${line//\`/\\\`}
    eval "echo \"$line\"" | tee -a "$effective_config_file"
  done < "$GITEA_RUNNER_CONFIG_TEMPLATE_FILE"
  echo "==========================================================="
else
  # 同样逐行渲染, 但不打印到控制台
  while IFS= read -r line; do
    line=${line//\"/\\\"}
    line=${line//\`/\\\`}
    eval "echo \"$line\"" >> "$effective_config_file"
  done < "$GITEA_RUNNER_CONFIG_TEMPLATE_FILE"
fi


#################################################
# 注册 runner (若未注册过则向 Gitea 实例注册)
#################################################
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
  if [[ $GITEA_RUNNER_EPHEMERAL == "true" || $GITEA_RUNNER_EPHEMERAL == "1" ]]; then
    log INFO "  GITEA_RUNNER_EPHEMERAL=$GITEA_RUNNER_EPHEMERAL (runner will exit after completing one job)"
  fi
  # 带超时的重试注册循环
  wait_until=$(( $(date +%s) + GITEA_RUNNER_REGISTRATION_TIMEOUT ))
  while true; do
    register_args=(
      --instance "$GITEA_INSTANCE_URL"
      --token    "$GITEA_RUNNER_REGISTRATION_TOKEN"
      --name     "$GITEA_RUNNER_NAME"
      --labels   "$GITEA_RUNNER_LABELS"
      --config   "$effective_config_file"
      --no-interactive
    )
    if [[ $GITEA_RUNNER_EPHEMERAL == "true" || $GITEA_RUNNER_EPHEMERAL == "1" ]]; then
      register_args+=(--ephemeral)  # 临时模式: 完成一个任务后自动退出
    fi
    if gitea-runner register "${register_args[@]}"; then
      break;
    fi
    if [ "$(date +%s)" -ge $wait_until ]; then
      log ERROR "Runner registration failed."
      exit 1
    fi
    sleep "$GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL"
  done
fi


#################################################
# 清除所有 GITEA_ 开头的环境变量, 避免触发弃用警告
#################################################
unset $(env | grep "^GITEA_" | cut -d= -f1)


#################################################
# 启动 Gitea Actions runner 守护进程
#################################################
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
  (set -x; service docker stop)
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
