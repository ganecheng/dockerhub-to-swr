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

# 使用CPU运行, 打开公网访问
cat /webui.py > webui.py

# 安装依赖
python3 -m venv .venv
source .venv/bin/activate
# 安装CPU版torch
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
# 删除包含torch的所有行
sed -i '/torch/d' requirements.txt
pip install -r requirements.txt

# 清理无用文件
sh /os_clean.sh
