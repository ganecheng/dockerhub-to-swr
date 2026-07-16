# 基础镜像：Ubuntu 26.04 (resolute)
FROM ghcr.io/ganecheng/ubuntu:20260716_224412-x86_64

# 构建参数：dumbproxy 版本号
ARG DUMBPROXY_VERSION=1.51.1

# 下载并安装 dumbproxy 二进制文件
RUN <<EOF
  # 封装 curl：统一超时和重试策略
  function curl() {
    command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
  }

  arch=$(dpkg --print-architecture)

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
ENV CA_CERT_DIR='/opt/cloud/security/cert/ca'

# 复制启动脚本到镜像
COPY dumbproxy/run.sh /opt/

# dumbproxy 监听端口
EXPOSE 8080/tcp

# 使用 tini 作为 PID 1，正确处理信号和僵尸进程
# 以 root 用户启动，docker run 时可追加 dumbproxy 参数（如 -auth）
ENTRYPOINT ["/usr/bin/tini", "--", "/bin/bash", "/opt/run.sh"]
CMD ["-bind-address", ":8080"]
