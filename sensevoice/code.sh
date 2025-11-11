#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 应用目录
cd /app

# 下载代码
git clone https://github.com/FunAudioLLM/SenseVoice.git . && git checkout 4462e35
git lfs install
git lfs pull

git lfs uninstall && rm -rf .git

# 安装依赖
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 清理无用文件
sh /os_clean.sh
