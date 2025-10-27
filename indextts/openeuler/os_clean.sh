#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 清理无用文件
uv cache clean
rm -rf /app/checkpoints/.cache /root/.cache/huggingface/xet /opt/conda
yum clean all && rm -rf /var/cache/* /var/log/* /var/tmp/* /tmp/*
yum -y autoremove git git-lfs