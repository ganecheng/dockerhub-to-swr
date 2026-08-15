#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 应用目录
cd /app

# 下载代码
git clone --filter=blob:none --no-checkout https://github.com/FunAudioLLM/SenseVoice.git .
git lfs install
git checkout 4462e35
git lfs pull

git lfs uninstall && rm -rf .git

# 使用GPU运行, 打开公网访问
cat /webui.py > webui.py

# 安装依赖（torch/torchaudio 已由 pytorch 基础镜像提供）
sed -i '/torch/d' requirements.txt
pip install --no-cache-dir -r requirements.txt

# 清理无用文件
sh /os_clean.sh
