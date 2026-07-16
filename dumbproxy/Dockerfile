# 基础镜像：Ubuntu 26.04 (resolute)
FROM ubuntu:resolute-20260610

# 构建参数：禁止 apt 交互式提示
ARG DEBIAN_FRONTEND=noninteractive
# 构建参数：dumbproxy 版本号
ARG DUMBPROXY_VERSION=1.51.1

# 使用 bash 严格模式执行 RUN 指令（出错即停、禁止未定义变量、管道失败传递）
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# 单个 RUN 层完成所有安装，减少镜像层数和体积
RUN <<EOF
  # 封装 curl：统一超时和重试策略
  function curl() {
    command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
  }

  arch=$(dpkg --print-architecture)

  # 将 /bin/sh 指向 bash（dash 不支持 source 命令，Gitea Runner 内部脚本依赖 bash 特性）
  ln -sf /bin/bash /bin/sh

  # 安装基础依赖：证书、下载工具、tini（PID 1 进程管理）、git
  # 以及常用运行时工具（语言包、字体、网络诊断、压缩、jq/openssl 等）
  apt-get update
  apt-get install --no-install-recommends -y \
    ca-certificates curl dos2unix iptables tini git \
    locales-all libfreetype6 net-tools findutils util-linux zip unzip bc fontconfig sudo jq openssl \
    iproute2 iputils-ping telnet bind9-dnsutils wget \
    zstd xz-utils bzip2 gzip vim tree \
    python3 python3-pip

  # 下载并安装 dumbproxy 二进制文件
  case "$arch" in
    amd64)
      dumbproxy_arch='linux-amd64'
      ;;
    arm64)
      dumbproxy_arch='linux-arm64'
      ;;
    *)
      echo "Unsupported architecture: $arch" >&2
      exit 1
      ;;
  esac
  dumbproxy_url="https://github.com/SenseUnit/dumbproxy/releases/download/v${DUMBPROXY_VERSION}/dumbproxy.${dumbproxy_arch}"
  echo "Downloading dumbproxy from $dumbproxy_url"
  curl "$dumbproxy_url" -o /usr/local/bin/dumbproxy
  chmod 755 /usr/local/bin/dumbproxy
  dumbproxy -version

  # 创建 dumbproxy 工作目录（autocert 缓存、凭证文件等）
  install -d -m 0755 /.dumbproxy

  # 清理缓存和临时文件，减小镜像体积
  rm -rf /var/cache/{apt,debconf} /var/lib/apt/lists/* /var/log/{apt,alternatives.log,bootstrap.log,dpkg.log} /tmp/* /var/tmp/*

EOF

# 默认环境变量：均可在 docker run 时覆盖
ENV TZ='Asia/Shanghai' \
    CA_CERT_DIR='/opt/cloud/security/cert/ca'

# 复制启动脚本到镜像
COPY dumbproxy/run.sh /opt/

# dumbproxy 监听端口
EXPOSE 8080/tcp

# 使用 tini 作为 PID 1，正确处理信号和僵尸进程
# 以 root 用户启动，docker run 时可追加 dumbproxy 参数（如 -auth）
ENTRYPOINT ["/usr/bin/tini", "--", "/bin/bash", "/opt/run.sh"]
CMD ["-bind-address", ":8080"]
