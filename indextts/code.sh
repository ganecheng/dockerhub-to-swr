#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 应用目录
cd /app

# 下载代码
git clone --filter=blob:none --no-checkout https://github.com/index-tts/index-tts.git .
git lfs install
git checkout v2.5.0
git lfs pull

git lfs uninstall && rm -rf .git

# 使用uv安装依赖
uv sync --extra webui --no-cache

# 清理无用文件
sh /os_clean.sh