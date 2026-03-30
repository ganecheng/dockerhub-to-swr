#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 应用目录
cd /default_comfyui_bundle

# 下载代码
git clone 'https://github.com/Comfy-Org/ComfyUI.git'
cd /default-comfyui-bundle/ComfyUI
# Using stable version (has a release tag)
git reset --hard "$(git tag | grep -e '^v' | sort -V | tail -1)"
rm -rf .git

# 安装依赖
pip install --no-cache-dir -r requirements.txt
pip install --no-cache-dir -r manager_requirements.txt

# 模型工具
uv tool install --no-cache "huggingface-hub[cli,hf_xet]"
uv tool install --no-cache "modelscope"

# 清理无用文件
sh /os_clean.sh