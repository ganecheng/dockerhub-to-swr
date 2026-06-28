# 基础镜像：Ubuntu 26.04 (resolute)
FROM ubuntu:resolute-20260610

# 构建参数：禁止 apt 交互式提示
ARG DEBIAN_FRONTEND=noninteractive
# 构建参数：Gitea Runner 版本号
ARG GITEA_RUNNER_VERSION=1.0.8

# 使用 bash 严格模式执行 RUN 指令（出错即停、禁止未定义变量、管道失败传递）
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# 单个 RUN 层完成所有安装，减少镜像层数和体积
RUN <<EOF
  # 封装 curl：统一超时和重试策略
  function curl() {
    command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
  }

  arch=$(dpkg --print-architecture)

  echo "Installing required packages..."
  # 安装基础依赖：证书、下载工具、tini（PID 1 进程管理）、Node.js、git
  apt-get update
  apt-get install --no-install-recommends -y ca-certificates curl wget tini nodejs npm git gnupg

  # 下载并安装 Gitea Runner 二进制文件
  echo "Downloading gitea-runner... "
  curl "https://gitea.com/gitea/runner/releases/download/v${GITEA_RUNNER_VERSION}/gitea-runner-${GITEA_RUNNER_VERSION}-linux-${arch}" -o /usr/local/bin/gitea-runner
  chmod 755 /usr/local/bin/gitea-runner
  gitea-runner --version

  # 安装 Docker 引擎（用于在容器内构建和运行镜像）
  echo "Installing docker engine..."
  install -m 0755 -d /etc/apt/keyrings
  curl "https://download.docker.com/linux/ubuntu/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  # 根据系统代号添加 Docker 官方 APT 源
  OS_CODENAME="$(source /etc/os-release && echo "$VERSION_CODENAME")"
  echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $OS_CODENAME stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  # 安装 Docker CE、Buildx 插件、Compose 插件、containerd
  (set -x; apt-get install --no-install-recommends -y docker-ce docker-buildx-plugin docker-compose-plugin containerd.io)

  # 验证 Docker 各组件安装成功
  docker --version && docker compose version && docker buildx version && runc --version

  # 修复 init.d/docker 中硬句柄限制的问题（部分系统会导致 Docker 启动失败）
  if [[ -f /etc/init.d/docker ]] && grep -q "ulimit -Hn" /etc/init.d/docker; then
    sed -i 's/ulimit -Hn/ulimit -n/g' /etc/init.d/docker
  fi

  # 切换 iptables 为 legacy 模式，兼容性更好
  update-alternatives --set iptables /usr/sbin/iptables-legacy
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

  # 下载与当前 Docker 版本匹配的 dind（Docker-in-Docker）hack 脚本
  docker_version=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
  dind_hack_url="https://raw.githubusercontent.com/moby/moby/v${docker_version}/hack/dind"
  curl "$dind_hack_url" -o /usr/local/bin/dind-hack
  chmod +x /usr/local/bin/dind-hack

  # 清理缓存和临时文件，减小镜像体积
  echo "Cleanup..."
  apt-get purge -y gnupg && apt-get autoremove --purge -y
  rm -rf /var/cache/{apt,debconf} /var/lib/apt/lists/* /var/log/{apt,alternatives.log,bootstrap.log,dpkg.log} /tmp/* /var/tmp/*

EOF

# 默认环境变量：均可在 docker run 时覆盖
ENV \
  INIT_SH_FILE='' \
  GITEA_RUNNER_CONFIG_TEMPLATE_FILE='/opt/config.template.yaml' \
  GITEA_RUNNER_NAME='' \
  GITEA_RUNNER_LABELS='' \
  GITEA_RUNNER_LABELS_DEFAULT='ubuntu-latest,ubuntu-26.04' \
  GITEA_RUNNER_EPHEMERAL=false \
  GITEA_RUNNER_REGISTRATION_TIMEOUT=30 \
  GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL=3

# 复制启动脚本和配置模板到镜像
COPY gitea-act-runner/*.sh /opt/
COPY gitea-act-runner/config.template.yaml /opt/

# Runner 数据卷（注册令牌、配置等）
VOLUME /data
# Docker 数据卷（镜像、容器层存储）
VOLUME /var/lib/docker

# 使用 tini 作为 PID 1，正确处理信号和僵尸进程
ENTRYPOINT ["/usr/bin/tini", "--"]

# 默认启动命令
CMD ["/bin/bash", "/opt/run.sh"]
