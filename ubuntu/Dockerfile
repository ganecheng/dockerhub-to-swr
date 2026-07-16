# 基础镜像：Ubuntu 26.04 (resolute)
FROM ubuntu:resolute-20260707

# 构建参数：禁止 apt 交互式提示
ARG DEBIAN_FRONTEND=noninteractive

# 使用 bash 严格模式执行 RUN 指令（出错即停、禁止未定义变量、管道失败传递）
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# 单个 RUN 层完成所有安装，减少镜像层数和体积
RUN <<EOF
  # 将 /bin/sh 指向 bash（dash 不支持 source 命令，Gitea Runner 内部脚本依赖 bash 特性）
  ln -sf /bin/bash /bin/sh

  # 安装基础依赖：证书、下载工具、tini（PID 1 进程管理）、git
  # 以及常用运行时工具（语言包、字体、网络诊断、压缩、jq/openssl 等）
  apt-get update
  apt-get upgrade -y
  apt-get install --no-install-recommends -y \
    ca-certificates curl dos2unix iptables tini git tzdata \
    locales libfreetype6 net-tools findutils util-linux zip unzip bc fontconfig sudo jq openssl \
    iproute2 iputils-ping telnet bind9-dnsutils wget \
    zstd xz-utils bzip2 gzip vim tree \
    python3 python3-pip

  # 设置中文环境
  locale-gen zh_CN.UTF-8 en_US.UTF-8

  # 创建默认目录
  mkdir -pv /opt/cloud/{bin,logs,config,security,web,data,tmp}

  # 支持ll命令, 启用颜色显示
  echo 'alias ls="ls --color=auto"' >> /etc/bash.bashrc
  echo 'alias l="ls -alh"' >> /etc/bash.bashrc
  echo 'alias ll="ls -alh"' >> /etc/bash.bashrc
  echo 'alias lll="ls -alh"' >> /etc/bash.bashrc

  # 清理缓存和临时文件，减小镜像体积
  rm -rf /var/cache/{apt,debconf} /var/lib/apt/lists/* /var/log/{apt,alternatives.log,bootstrap.log,dpkg.log} /tmp/* /var/tmp/*

EOF

# 默认环境变量
ENV TZ='Asia/Shanghai'
ENV LANG=zh_CN.UTF-8

# 使用 tini 作为 PID 1，正确处理信号和僵尸进程
ENTRYPOINT ["/usr/bin/tini", "--"]
