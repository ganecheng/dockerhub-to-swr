#!/usr/bin/env bash
# run.sh - Gitea Runner Windows 启动脚本 (Git Bash 版)
# 对应 Linux 版的 run.sh，功能包括：
#   1. 打印启动横幅和环境信息
#   2. 导入自定义 CA 证书 (Windows 证书存储)
#   3. 配置 NPM 国内镜像站
#   4. 加载自定义初始化脚本
#   5. 从模板渲染配置文件 (复用 Linux 版 bash eval 方案)
#   6. 注册 Runner (临时模式，带超时重试)
#   7. 启动守护进程并监控空闲超时

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
cat <<'EOF'
   _____ _ _               _____
  / ____(_) |             |  __ \
 | |  __ _| |_ ___  __ _  | |__) |   _ _ __  _ __   ___ _ __
 | | |_ | | __/ _ \/ _` | |  _  / | | | '_ \| '_ \ / _ \ '__|
 | |__| | | ||  __/ (_, | | | \ \ |_| | | | | | | |  __/ |
  \_____|_|\__\___|\__,_| |_|  \_\__,_|_| |_|_| |_|\___|_|
EOF

echo

log INFO "$(gitea-runner --version)"
log INFO "Hostname: $COMPUTERNAME"

# 从 Windows ipconfig 输出提取 IPv4 地址（Server Core 自带命令，避免依赖 PowerShell 解析）
# 以 ": " 作为分隔符取第二列，匹配含 "IPv4" 的行
log INFO "IP Addresses: "
ipconfig | awk -F': ' '/IPv4/ { print " - " $2 }'

log INFO "Config environment variables: "
# 输出 GITEA_/ACT_ 开头的环境变量，对敏感信息（TOKEN/SECRET/PASSWORD）脱敏
env | grep -E '^(GITEA_|ACT_)' | sort | sed -E 's/^([^=]*(TOKEN|SECRET|PASSWORD)[^=]*=).*/\1******/I; s/^/ - /'


#################################################################
# 检查符号链接权限（诊断信息）
#################################################################
if /c/Windows/System32/whoami.exe /priv 2>/dev/null | grep -q 'SeCreateSymbolicLinkPrivilege'; then
  log INFO "SeCreateSymbolicLinkPrivilege: OK"
else
  log WARNING "SeCreateSymbolicLinkPrivilege not found in user token - symlink creation may fail"
fi


#################################################################
# 导入自定义 CA 证书（若挂载目录存在证书文件）
# 系统侧：通过 certutil 导入到 Windows 根证书存储
#################################################################
if [[ -d "${CA_CERT_DIR:-}" ]] && [[ -n "$(ls -A "${CA_CERT_DIR}" 2>/dev/null)" ]]; then
  log INFO "Importing CA certificates from ${CA_CERT_DIR} ..."
  counter=0
  for file in "${CA_CERT_DIR}"/*; do
    [[ -f "$file" ]] || continue
    counter=$((counter + 1))
    log INFO "  Importing $(basename "$file") ..."
    # certutil 是 Windows 原生命令，可识别符号链接或反斜杠形式的 Windows 路径
    certutil -addstore -f root "$file"
  done
  log INFO "Imported $counter CA certificate(s)."
else
  log INFO "No CA certificates to import (directory ${CA_CERT_DIR:-} empty or missing)."
fi


#################################################################
# 配置 NPM 默认镜像仓库
#################################################################
npm config set registry "${NPM_REGISTRY}"
log INFO "NPM registry set to ${NPM_REGISTRY}"


#################################################################
# 加载自定义初始化脚本 (如指定了 INIT_SH_FILE)
#################################################################
if [[ -f "${INIT_SH_FILE:-}" ]]; then
  log INFO "Loading [${INIT_SH_FILE}]..."
  # shellcheck source=/dev/null
  source "${INIT_SH_FILE}"
fi


#################################################################
# 从模板渲染配置文件 (用环境变量替换模板中的占位符)
# 直接复用 Linux 版的 bash eval 方案：逐行读取、eval echo 展开变量；
# 同时支持 ${VAR:-default} 和 ${VAR//old/new} 两种 bash 风格占位符，
# 比 PowerShell 的正则手动替换更原生且无 UTF-8 编码陷阱。
#################################################################
# 若未指定 runner 标签, 则使用默认标签
if [[ -z "${GITEA_RUNNER_LABELS:-}" ]]; then
  GITEA_RUNNER_LABELS=$GITEA_RUNNER_LABELS_DEFAULT
fi

# 输出到 C:/opt/gitea_runner_config.yml，与原 run.ps1 行为一致；
# 使用正斜杠写法在 bash 重定向与 Windows 原生工具之间都能直接生效
effective_config_file='C:/opt/gitea_runner_config.yml'
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
data_dir='C:/data'
mkdir -p "$data_dir"
cd "$data_dir" || exit 1

registration_file="$data_dir/.runner"
if [[ ! -s "$registration_file" ]]; then
  # 未直接提供 token 时, 从文件读取（仅存入当前 shell 变量，不导出避免泄漏）
  if [[ -z "${GITEA_RUNNER_REGISTRATION_TOKEN:-}" ]]; then
    read -r GITEA_RUNNER_REGISTRATION_TOKEN < "$GITEA_RUNNER_REGISTRATION_TOKEN_FILE"
  fi

  log INFO "Trying to register runner with Gitea..."
  log INFO "  GITEA_INSTANCE_URL=$GITEA_INSTANCE_URL"
  log INFO "  GITEA_RUNNER_NAME=$GITEA_RUNNER_NAME"
  log INFO "  GITEA_RUNNER_REGISTRATION_TOKEN=${GITEA_RUNNER_REGISTRATION_TOKEN//?/*}"  # token 用星号遮掩
  log INFO "  GITEA_RUNNER_LABELS=$GITEA_RUNNER_LABELS"
  log INFO "  Ephemeral mode enabled (runner will exit after completing one job)"

  # 使用 --flag=value 形式（而非 --flag value 两元素），保留与原 run.ps1 一致的行为：
  # 在 shell 与 Go pflag 之间不传递空 token 也不触发 cobra MaximumNArgs(0) 校验失败。
  register_args=(
    "--instance=$GITEA_INSTANCE_URL"
    "--token=$GITEA_RUNNER_REGISTRATION_TOKEN"
    "--name=$GITEA_RUNNER_NAME"
    "--labels=$GITEA_RUNNER_LABELS"
    "--config=$effective_config_file"
    --no-interactive
    --ephemeral
  )

  timeout_seconds=$GITEA_RUNNER_REGISTRATION_TIMEOUT
  retry_interval=$GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL
  deadline=$(( $(date +%s) + timeout_seconds ))
  while true; do
    if gitea-runner register "${register_args[@]}"; then
      break
    fi
    if [[ $(date +%s) -ge $deadline ]]; then
      log ERROR "Runner registration failed."
      exit 1
    fi
    sleep "$retry_interval"
  done
fi


#################################################################
# 保存超时配置（unset 后仍可使用），然后清除所有 GITEA_ 环境变量
#################################################################
runner_timeout_minutes=$GITEA_RUNNER_TIMEOUT_MINUTES
for var in "${!GITEA_@}"; do
  unset "$var"
done


#################################################################
# 启动 Gitea Actions runner 守护进程
#################################################################
daemon_log='C:/opt/daemon.log'
daemon_err='C:/opt/daemon.err'

# 后台启动 daemon，stdout/stderr 重定向到日志文件
# Git Bash 的 $! 返回 MSYS2 fork 的 PID，可用 kill -0 检测存活
gitea-runner daemon --config "$effective_config_file" \
  > "$daemon_log" 2> "$daemon_err" &
gitea_runner_pid=$!

# 计算超时时间戳（默认 60 分钟）
timeout_seconds=$((runner_timeout_minutes * 60))
deadline=$(( $(date +%s) + timeout_seconds ))
log INFO "Container timeout: ${runner_timeout_minutes}m (will exit after $(date -d "@$deadline" '+%H:%M:%S'))"

# 捕获退出信号：直接结束，容器销毁后内核自动回收子进程
trap 'log INFO "Received signal, exiting..."; exit 1' INT TERM HUP QUIT

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
  if [[ $task_detected == false ]] && grep -qiE "task [0-9]+ repo|Running job" "$daemon_log" "$daemon_err" 2>/dev/null; then
    task_detected=true
    deadline=$(( $(date +%s) + timeout_seconds ))
    log INFO "Task received from server, timeout extended to ${runner_timeout_minutes}m (will exit after $(date -d "@$deadline" '+%H:%M:%S'))"
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