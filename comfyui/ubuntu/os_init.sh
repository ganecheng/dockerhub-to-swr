#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 启动命令
chmod 777 /run.sh

# 应用目录
mkdir -pv /default_comfyui_bundle

# 软件安装
apt-get update && apt-get install -y vim git git-lfs net-tools tree curl wget python3 python3-pip

# 设置全局python命令
ln -s /usr/bin/python3 /usr/bin/python

# 使用uv安装依赖
pip install --no-cache-dir -U uv

# 清理无用文件
sh /os_clean.sh