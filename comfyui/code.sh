#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 应用目录
cd /app

# 下载代码
git clone https://github.com/Comfy-Org/ComfyUI.git . && git checkout v0.18.2
git lfs install
git lfs pull

git lfs uninstall && rm -rf .git

# 安装依赖
pip install --no-cache-dir -r requirements.txt
pip install --no-cache-dir -r manager_requirements.txt

# 使用uv安装依赖
pip install --no-cache-dir -U uv

# 模型工具
uv tool install "huggingface-hub[cli,hf_xet]"
uv tool install "modelscope"

# 清理无用文件
sh /os_clean.sh