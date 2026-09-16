# 构建参数：基础镜像架构后缀（x86_64 / aarch64）
ARG BASE_ARCH=x86_64

# 基础镜像：Ubuntu 26.04 (resolute)
FROM ghcr.io/ganecheng/ubuntu:20260914_212511-${BASE_ARCH}

# 构建参数：Gitea Runner 版本号
ARG GITEA_RUNNER_VERSION=3.5.0
# 构建参数：Docker 引擎版本号（静态二进制）
ARG DOCKER_VERSION=28.5.2
# 构建参数：Node.js 版本号
ARG NODE_VERSION=24.21.0
# 构建参数：Qwen Code 版本号
ARG QWEN_CODE_VERSION=0.23.4
# 构建参数：kubectl 版本号
ARG KUBECTL_VERSION=1.37.0
# 构建参数：Helm 版本号
ARG HELM_VERSION=4.3.0
# 构建参数：Runner 默认标签的架构后缀（x86_64 构建为空，aarch64 构建为 -aarch64）
ARG ARCH_SUFFIX

# 单个 RUN 层完成所有安装，减少镜像层数和体积
RUN <<EOF
  # 封装 curl：统一超时和重试策略
  function curl() {
    command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
  }

  # 创建后续所需的目录
  install -m 0755 -d /etc/docker /data

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

  # 通过 npm 全局安装 Qwen Code CLI（安装到 /usr/local，与 Node.js 同目录，已在 PATH 中）
  npm install -g "@qwen-code/qwen-code@${QWEN_CODE_VERSION}"
  qwen --version

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

  # 下载并安装 kubectl
  curl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${arch}/kubectl" -o /usr/local/bin/kubectl
  chmod 755 /usr/local/bin/kubectl
  kubectl version --client --output=yaml

  # 下载并安装 Helm
  curl "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${arch}.tar.gz" -o /tmp/helm.tar.gz
  tar -xzf /tmp/helm.tar.gz -C /usr/local/bin --strip-components=1 linux-${arch}/helm
  rm -f /tmp/helm.tar.gz
  helm version

  # 切换 iptables 为 legacy 模式，兼容性更好
  update-alternatives --set iptables /usr/sbin/iptables-legacy
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

  # 下载 dind 辅助脚本
  curl "https://raw.githubusercontent.com/moby/moby/master/hack/dind" -o /usr/local/bin/dind-hack
  chmod +x /usr/local/bin/dind-hack

  # 配置 Docker daemon 开启 experimental 模式（支持 --squash）
  echo '{"experimental":true}' > /etc/docker/daemon.json

EOF

# 默认环境变量：均可在 docker run 时覆盖
ENV \
  INIT_SH_FILE='' \
  CA_CERT_DIR='/opt/cloud/security/cert/ca' \
  NPM_REGISTRY='https://mirrors.huaweicloud.com/repository/npm/' \
  NODE_USE_SYSTEM_CA=1 \
  APT_MIRROR_URI='https://mirrors.huaweicloud.com/ubuntu/' \
  PIP_INDEX_URL='https://mirrors.huaweicloud.com/repository/pypi/simple' \
  PIP_TRUSTED_HOST='mirrors.huaweicloud.com' \
  GITEA_RUNNER_CONFIG_TEMPLATE_FILE='/opt/config.template.yaml' \
  GITEA_RUNNER_NAME='' \
  GITEA_RUNNER_LABELS='' \
  GITEA_RUNNER_LABELS_DEFAULT="ubuntu${ARCH_SUFFIX}-latest,ubuntu${ARCH_SUFFIX}-26.04" \
  GITEA_RUNNER_REGISTRATION_TIMEOUT=30 \
  GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL=3 \
  GITEA_RUNNER_TIMEOUT_MINUTES=60

# 复制启动脚本和配置模板到镜像
COPY gitea-runner-ubuntu/run.sh /opt/
COPY gitea-runner-ubuntu/config.template.yaml /opt/

# 复制 qwen 流式输出格式化脚本（供 job 内 qwen 的 stream-json 输出使用）
# 与 Windows 版 Runner 共用仓库内同一份脚本
COPY common/fmt_stream.py /opt/fmt_stream.py

# Docker 数据卷（镜像、容器层存储）
VOLUME /var/lib/docker

# 默认启动命令
CMD ["/bin/bash", "/opt/run.sh"]
