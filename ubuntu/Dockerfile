# 基础镜像：Ubuntu 26.04 (resolute)
FROM ubuntu:resolute-20260811.1

# 环境变量：禁止 apt 交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 允许 pip 在受外部管理的系统环境中直接安装包（绕过 PEP 668 限制）
ENV PIP_BREAK_SYSTEM_PACKAGES=1
# 禁止生成 .pyc 字节码缓存文件，减小镜像体积
ENV PYTHONDONTWRITEBYTECODE=1
# 强制 stdout/stderr 无缓冲输出，确保 docker logs 实时可见
ENV PYTHONUNBUFFERED=1
# 抑制 pip 以 root 用户运行时的警告输出
ENV PIP_ROOT_USER_ACTION=ignore

# 使用 bash 严格模式执行 RUN 指令（出错即停、禁止未定义变量、管道失败传递）
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# 单个 RUN 层完成所有安装，减少镜像层数和体积
RUN <<EOF
  # 将 /bin/sh 指向 bash（dash 不支持 source 命令，Gitea Runner 内部脚本依赖 bash 特性）
  ln -sf /bin/bash /bin/sh

  # 按功能类别分组安装，减少镜像层数和体积
  apt-get update
  apt-get upgrade -y
  apt-get install --no-install-recommends -y \
    ca-certificates curl wget tini tzdata \
    git git-lfs \
    locales fontconfig libfreetype6 \
    findutils util-linux binutils bc file \
    net-tools iproute2 iputils-ping telnet bind9-dnsutils \
    zip unzip zstd xz-utils bzip2 gzip dos2unix \
    vim tree jq yq \
    sudo openssl iptables \
    python3 python3-pip python3-venv skopeo

  # 验证 Python 安装
  python3 --version
  pip3 --version

  # 设置中文环境
  locale-gen zh_CN.UTF-8 en_US.UTF-8

  # 创建默认目录
  mkdir -pv /opt/cloud/{bin,logs,config,security,web,data,tmp}

  # 支持 ll 命令, 启用颜色显示
  echo 'alias ls="ls --color=auto"' >> /etc/bash.bashrc
  echo 'alias l="ls -alh"' >> /etc/bash.bashrc
  echo 'alias ll="ls -alh"' >> /etc/bash.bashrc
  echo 'alias lll="ls -alh"' >> /etc/bash.bashrc
  echo 'alias ..="cd .."' >> /etc/bash.bashrc
  echo 'alias l="ls -alh"' >> /root/.bashrc
  echo 'alias ll="ls -alh"' >> /root/.bashrc
  echo 'alias lll="ls -alh"' >> /root/.bashrc
  echo 'alias ..="cd .."' >> /root/.bashrc

  # 清理缓存和临时文件，减小镜像体积
  rm -rf /var/cache/{apt,debconf} /var/lib/apt/lists/* /var/log/{apt,alternatives.log,bootstrap.log,dpkg.log} /tmp/* /var/tmp/*

EOF

# 默认环境变量
ENV TZ='Asia/Shanghai'
ENV LANG=zh_CN.UTF-8

# 使用 tini 作为 PID 1，正确处理信号和僵尸进程
ENTRYPOINT ["/usr/bin/tini", "--"]
