#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 清理无用文件（/opt/conda 是基础镜像的 Python 环境，禁止删除）
apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
uv cache clean
rm -rf /root/.cache/huggingface/xet /root/.cache/pip
apt-get autoremove -y
