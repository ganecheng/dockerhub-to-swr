# 基础镜像：Ubuntu 26.04 (resolute)
FROM ubuntu:resolute-20260610

# 构建参数：禁止 apt 交互式提示
ARG DEBIAN_FRONTEND=noninteractive
# 构建参数：Gitea Runner 版本号
ARG GITEA_RUNNER_VERSION=1.0.8
# 构建参数：Docker 引擎版本号（静态二进制）
ARG DOCKER_VERSION=28.5.2

# 使用 bash 严格模式执行 RUN 指令（出错即停、禁止未定义变量、管道失败传递）
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# 单个 RUN 层完成所有安装，减少镜像层数和体积
RUN <<EOF
  # 封装 curl：统一超时和重试策略
  function curl() {
    command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
  }

  arch=$(dpkg --print-architecture)
  # Docker 静态二进制使用 uname 架构命名（amd64 → x86_64, arm64 → aarch64）
  docker_arch=$(uname -m)

  # 将 /bin/sh 指向 bash（dash 不支持 source 命令，Gitea Runner 内部脚本依赖 bash 特性）
  ln -sf /bin/bash /bin/sh

  # 安装基础依赖：证书、下载工具、tini（PID 1 进程管理）、Node.js、git
  apt-get update
  apt-get install --no-install-recommends -y ca-certificates curl dos2unix iptables tini nodejs npm git

  # 下载并安装 Gitea Runner 二进制文件
  curl "https://gitea.com/gitea/runner/releases/download/v${GITEA_RUNNER_VERSION}/gitea-runner-${GITEA_RUNNER_VERSION}-linux-${arch}" -o /usr/local/bin/gitea-runner
  chmod 755 /usr/local/bin/gitea-runner
  gitea-runner --version

  # 下载并解压 Docker 静态二进制
  curl "https://download.docker.com/linux/static/stable/${docker_arch}/docker-${DOCKER_VERSION}.tgz" -o /tmp/docker.tgz
  tar -xzf /tmp/docker.tgz -C /usr/local/bin --strip-components=1
  rm -f /tmp/docker.tgz

  # 验证 Docker 版本
  docker --version

  # 切换 iptables 为 legacy 模式，兼容性更好
  update-alternatives --set iptables /usr/sbin/iptables-legacy
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

  # 下载 dind 辅助脚本
  curl "https://raw.githubusercontent.com/moby/moby/master/hack/dind" -o /usr/local/bin/dind-hack
  chmod +x /usr/local/bin/dind-hack

  # 配置 Docker daemon 开启 experimental 模式（支持 --squash）
  install -m 0755 -d /etc/docker
  echo '{"experimental":true}' > /etc/docker/daemon.json

  # 清理缓存和临时文件，减小镜像体积
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
COPY gitea-runner/run.sh /opt/
COPY gitea-runner/config.template.yaml /opt/

# Runner 数据卷（注册令牌、配置等）
VOLUME /data
# Docker 数据卷（镜像、容器层存储）
VOLUME /var/lib/docker

# 使用 tini 作为 PID 1，正确处理信号和僵尸进程
ENTRYPOINT ["/usr/bin/tini", "--"]

# 默认启动命令
CMD ["/bin/bash", "/opt/run.sh"]
