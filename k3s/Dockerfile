# 基础镜像：Ubuntu 26.04 (resolute)
FROM ubuntu:resolute-20260627

# 构建参数：禁止 apt 交互式提示
ARG DEBIAN_FRONTEND=noninteractive
# 构建参数：k3s 版本号，留空时下载最新发布版二进制文件
ARG K3S_VERSION='v1.34.9+k3s1'

# 使用 bash 严格模式执行 RUN 指令（出错即停、禁止未定义变量、管道失败传递）
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# 单个 RUN 层完成所有安装，减少镜像层数和体积
RUN <<EOF
  # 封装 curl：统一超时和重试策略
  function curl() {
    command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
  }

  arch=$(dpkg --print-architecture)

  # 安装基础依赖：证书、下载工具、tini（PID 1 进程管理）和 k3s/Docker 运行所需工具
  apt-get update
  apt-get install --no-install-recommends -y ca-certificates curl tini iproute2 iptables kmod procps zstd

  # 安装 Docker 引擎（用于在容器内构建和运行镜像）
  install -m 0755 -d /etc/apt/keyrings
  curl "https://download.docker.com/linux/ubuntu/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # 根据系统代号添加 Docker 官方 APT 源
  OS_CODENAME="$(source /etc/os-release && echo "$VERSION_CODENAME")"
  echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $OS_CODENAME stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  # 安装 Docker CE；containerd.io 是 Docker CE 的运行依赖，k3s 默认通过 --docker 使用 Docker。
  (set -x; apt-get install --no-install-recommends -y docker-ce containerd.io)

  # 验证 Docker 各组件安装成功
  docker --version && runc --version

  # 直接下载 k3s 二进制文件，避免官方安装脚本在容器构建阶段要求 systemd/openrc
  case "$arch" in
    amd64)
      k3s_arch=''
      k3s_airgap_arch='-amd64'
      ;;
    arm64)
      k3s_arch='-arm64'
      k3s_airgap_arch='-arm64'
      ;;
    *)
      echo "Unsupported architecture: $arch" >&2
      exit 1
      ;;
  esac
  if [[ -n "$K3S_VERSION" ]]; then
    k3s_url="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s${k3s_arch}"
    k3s_airgap_url="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-airgap-images${k3s_airgap_arch}.tar.zst"
  else
    k3s_url="https://github.com/k3s-io/k3s/releases/latest/download/k3s${k3s_arch}"
    k3s_airgap_url="https://github.com/k3s-io/k3s/releases/latest/download/k3s-airgap-images${k3s_airgap_arch}.tar.zst"
  fi
  echo "Downloading k3s from $k3s_url"
  curl "$k3s_url" -o /usr/local/bin/k3s
  chmod 755 /usr/local/bin/k3s
  ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl
  k3s --version
  kubectl version --client=true

  # 内置 k3s airgap 镜像包，启动脚本会恢复到 k3s 数据目录并导入 Docker。
  install -d /opt/k3s
  echo "Downloading k3s airgap images from $k3s_airgap_url"
  curl "$k3s_airgap_url" -o /opt/k3s/k3s-airgap-images.tar.zst

  # 修复 init.d/docker 中硬句柄限制的问题（部分系统会导致 Docker 启动失败）
  if [[ -f /etc/init.d/docker ]] && grep -q "ulimit -Hn" /etc/init.d/docker; then
    sed -i 's/ulimit -Hn/ulimit -n/g' /etc/init.d/docker
  fi

  # 将 Docker data-root 设置到 /var/lib/rancher/k3s/docker，
  # 使其落在 k3s 的 PVC 之下，只需持久化一个目录即可保留集群状态和容器数据
  install -d /etc/docker
  cat > /etc/docker/daemon.json <<'EOF_DOCKER'
{"data-root": "/var/lib/rancher/k3s/docker"}
EOF_DOCKER

  # 切换 iptables 为 legacy 模式，兼容性更好
  update-alternatives --set iptables /usr/sbin/iptables-legacy
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

  # 下载 dind 辅助脚本
  curl "https://raw.githubusercontent.com/moby/moby/master/hack/dind" -o /usr/local/bin/dind-hack
  chmod +x /usr/local/bin/dind-hack

  # 清理缓存和临时文件，减小镜像体积
  rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.asc
  rm -rf /var/cache/{apt,debconf} /var/lib/apt/lists/* /var/log/{apt,alternatives.log,bootstrap.log,dpkg.log} /tmp/* /var/tmp/*

  # 设置华为云镜像站作为默认 APT 源
  rm -rf /etc/apt/sources.list.d/*
  cat >>/etc/apt/sources.list.d/ubuntu_HuaweiCloud.sources <<'EOF_APT'
Types: deb
URIs: https://mirrors.huaweicloud.com/ubuntu/
Suites: resolute resolute-updates resolute-security
Components: main universe restricted
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF_APT
  apt-get update

EOF

# 复制启动脚本到镜像
COPY k3s/run.sh /opt/

# k3s 数据卷（集群状态 + Docker 容器数据，通过 daemon.json 指向同一目录）
VOLUME /var/lib/rancher/k3s

# 使用 tini 作为 PID 1，正确处理信号和僵尸进程
ENTRYPOINT ["/usr/bin/tini", "--"]

# 默认启动命令
CMD ["/bin/bash", "/opt/run.sh"]
