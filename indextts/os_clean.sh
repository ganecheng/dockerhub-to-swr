#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 清理无用文件
apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
uv cache clean
rm -rf /app/checkpoints/.cache /root/.cache/huggingface/xet /opt/conda
apt-get autoremove -y
apt-get remove -y git git-lfs || true
