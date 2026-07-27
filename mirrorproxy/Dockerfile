# 基础镜像：Ubuntu 26.04 (resolute)
FROM ghcr.io/ganecheng/ubuntu:20260725_145405-x86_64

# 构建参数：mirrorproxy-server 版本号
ARG MIRRORPROXY_VERSION=1.1.0

# 下载并安装 mirrorproxy-server 二进制文件
RUN <<EOF
  # 封装 curl：统一超时和重试策略
  function curl() {
    command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
  }

  arch=$(dpkg --print-architecture)

  case "$arch" in
    amd64)
      mirrorproxy_arch='x86_64-unknown-linux-musl'
      ;;
    arm64)
      mirrorproxy_arch='aarch64-unknown-linux-gnu'
      ;;
    *)
      echo "Unsupported architecture: $arch" >&2
      exit 1
      ;;
  esac

  mirrorproxy_url="https://github.com/inbjo/MirrorProxy/releases/download/v${MIRRORPROXY_VERSION}/mirrorproxy-server-${mirrorproxy_arch}.tar.gz"
  echo "Downloading mirrorproxy-server from $mirrorproxy_url"
  curl "$mirrorproxy_url" -o /tmp/mirrorproxy-server.tar.gz
  tar -xzf /tmp/mirrorproxy-server.tar.gz -C /tmp/
  install -m 0755 /tmp/mirrorproxy-server /usr/local/bin/mirrorproxy-server
  rm -f /tmp/mirrorproxy-server.tar.gz /tmp/mirrorproxy-server
  mirrorproxy-server --version

  # 创建 mirrorproxy 数据目录（SQLite 数据库、缓存等）
  install -d -m 0755 /data

  # 清理缓存和临时文件，减小镜像体积
  rm -rf /var/cache/{apt,debconf} /var/lib/apt/lists/* /var/log/{apt,alternatives.log,bootstrap.log,dpkg.log} /tmp/* /var/tmp/*

EOF

# 默认环境变量：均可在 docker run 时覆盖
ENV CA_CERT_DIR='/opt/cloud/security/cert/ca'
ENV MIRRORPROXY_LISTEN_ADDR='0.0.0.0:3000'
ENV MIRRORPROXY_DB='/data/mirrorproxy.sqlite3'

# 复制启动脚本到镜像
COPY mirrorproxy/run.sh /opt/

# mirrorproxy-server 监听端口
EXPOSE 3000/tcp

# 默认启动命令
CMD ["/bin/bash", "/opt/run.sh"]
