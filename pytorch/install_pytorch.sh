#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

pip install --no-cache-dir torch>=2.11.0,<2.12.0 torchvision>=0.26.0,<0.27.0 torchaudio>=2.11.0,<2.12.0 --index-url https://download.pytorch.org/whl/cu130

# 清理无用文件
sh /os_clean.sh