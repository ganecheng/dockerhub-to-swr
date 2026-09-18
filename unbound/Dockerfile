# 基础镜像：Ubuntu 26.04 (resolute)
FROM ghcr.io/ganecheng/ubuntu:20260918_214210-x86_64

# 从 Ubuntu apt 仓库安装 unbound（验证性递归缓存 DNS 解析器）
RUN <<EOF
  apt-get update
  apt-get install --no-install-recommends -y unbound unbound-anchor
  unbound -V

  # 清理缓存和临时文件，减小镜像体积
  rm -rf /var/cache/{apt,debconf} /var/lib/apt/lists/* /var/log/{apt,alternatives.log,bootstrap.log,dpkg.log} /tmp/* /var/tmp/*

EOF

# 默认环境变量：均可在 docker run 时覆盖
ENV CA_CERT_DIR='/opt/cloud/security/cert/ca'
ENV UNBOUND_PORT='53'
ENV UNBOUND_ALLOWED_NETS='0.0.0.0/0'
ENV UNBOUND_FORWARD_TLS='0'

# 复制启动脚本到镜像
COPY unbound/run.sh /opt/

# unbound 监听端口
EXPOSE 53/tcp
EXPOSE 53/udp

# 默认启动命令
CMD ["/bin/bash", "/opt/run.sh"]
