#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 启动命令
chmod 777 /run.sh

# 应用目录
mkdir -pv /app
cd /app

# 软件安装
apt-get update && apt-get install -y git git-lfs net-tools tree curl wget python3 python3-pip

# 安装PyTorch
pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130
