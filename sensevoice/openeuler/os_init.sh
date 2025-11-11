#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 启动命令
chmod 777 /run.sh

# 应用目录
mkdir -pv /app
cd /app

# 软件安装
yum clean all && yum makecache && yum -y upgrade
yum install -y glibc-all-langpacks freetype net-tools dos2unix findutils util-linux zip unzip bc fontconfig sudo jq openssl
yum install -y iproute iputils telnet bind-utils
yum install -y git git-lfs tree curl wget python3 python3-pip ffmpeg
