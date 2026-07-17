# 基础镜像：Ubuntu 26.04 (resolute)
FROM ghcr.io/ganecheng/ubuntu:20260717_210657-x86_64

# 构建参数：Gitea Runner 版本号
ARG GITEA_RUNNER_VERSION=1.0.8
# 构建参数：Docker 引擎版本号（静态二进制）
ARG DOCKER_VERSION=28.5.2
# 构建参数：Node.js 版本号
ARG NODE_VERSION=24.18.0

# 单个 RUN 层完成所有安装，减少镜像层数和体积
RUN <<EOF
  # 封装 curl：统一超时和重试策略
  function curl() {
    command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
  }

  arch=$(dpkg --print-architecture)
  # Docker 静态二进制使用 uname 架构命名（amd64 -> x86_64, arm64 -> aarch64）
  docker_arch=$(uname -m)
  # Node.js 预编译二进制使用自身命名（amd64 -> x64, arm64 -> arm64）
  node_arch=$([ "${arch}" = "amd64" ] && echo "x64" || echo "${arch}")

  # 安装 Node.js（自带 npm）via 官方预编译二进制
  curl "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" -o /tmp/node.tar.xz
  tar -xf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner
  rm -f /tmp/node.tar.xz
  node --version
  npm --version

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

EOF

# 默认环境变量：均可在 docker run 时覆盖
ENV \
  INIT_SH_FILE='' \
  CA_CERT_DIR='/opt/cloud/security/cert/ca' \
  NPM_REGISTRY='https://mirrors.huaweicloud.com/repository/npm/' \
  APT_MIRROR_URI='https://mirrors.huaweicloud.com/ubuntu/' \
  PIP_INDEX_URL='https://mirrors.huaweicloud.com/repository/pypi/simple' \
  PIP_TRUSTED_HOST='mirrors.huaweicloud.com' \
  GITEA_RUNNER_CONFIG_TEMPLATE_FILE='/opt/config.template.yaml' \
  GITEA_RUNNER_NAME='' \
  GITEA_RUNNER_LABELS='' \
  GITEA_RUNNER_LABELS_DEFAULT='ubuntu-latest,ubuntu-26.04' \
  GITEA_RUNNER_REGISTRATION_TIMEOUT=30 \
  GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL=3 \
  GITEA_RUNNER_TIMEOUT_MINUTES=60

# 复制启动脚本和配置模板到镜像
COPY gitea-runner/run.sh /opt/
COPY gitea-runner/config.template.yaml /opt/

# Runner 数据卷（注册令牌、配置等）
VOLUME /data
# Docker 数据卷（镜像、容器层存储）
VOLUME /var/lib/docker

# 默认启动命令
CMD ["/bin/bash", "/opt/run.sh"]
