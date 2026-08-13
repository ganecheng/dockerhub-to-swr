#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

pip install --no-cache-dir \
    torch==2.12.* \
    torchvision==0.27.* \
    torchcodec==0.12.* \
    --index-url https://download.pytorch.org/whl/cu132

# torchaudio 2.11.0 未发布 cu132 wheel，从 cu130 索引安装；--no-deps 避免 cu130 版 torch 覆盖
pip install --no-cache-dir --no-deps torchaudio==2.11.* \
    --index-url https://download.pytorch.org/whl/cu130

# 清理无用文件
sh /os_clean.sh
