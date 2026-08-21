# 基础镜像：Ubuntu 26.04 (resolute)
FROM ghcr.io/ganecheng/ubuntu:20260821_205550-x86_64

# 构建参数：ttyd 版本号
ARG TTYD_VERSION=1.7.7

# 下载并安装 ttyd 二进制文件
RUN <<EOF
  # 封装 curl：统一超时和重试策略
  function curl() {
    command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
  }

  arch=$(dpkg --print-architecture)

  case "$arch" in
    amd64)
      ttyd_arch='x86_64'
      ;;
    arm64)
      ttyd_arch='aarch64'
      ;;
    *)
      echo "Unsupported architecture: $arch" >&2
      exit 1
      ;;
  esac

  ttyd_url="https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${ttyd_arch}"
  echo "Downloading ttyd from $ttyd_url"
  curl "$ttyd_url" -o /usr/local/bin/ttyd
  chmod 755 /usr/local/bin/ttyd
  ttyd --version

  # 清理缓存和临时文件，减小镜像体积
  rm -rf /var/cache/{apt,debconf} /var/lib/apt/lists/* /var/log/{apt,alternatives.log,bootstrap.log,dpkg.log} /tmp/* /var/tmp/*

EOF

# 默认环境变量：均可在 docker run 时覆盖
ENV CA_CERT_DIR='/opt/cloud/security/cert/ca'
ENV TTYD_PORT='7681'
ENV TTYD_COMMAND='bash'

# 复制启动脚本到镜像
COPY ttyd/run.sh /opt/

# ttyd 监听端口
EXPOSE 7681/tcp

# 默认启动命令
CMD ["/bin/bash", "/opt/run.sh"]
