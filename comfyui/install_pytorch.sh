#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu130

# 清理无用文件
sh /os_clean.sh