#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 应用目录
mkdir -pv /default_comfyui_bundle/ComfyUI
cd /default_comfyui_bundle/ComfyUI

# 下载代码
git clone https://github.com/Comfy-Org/ComfyUI.git . && git checkout 3086026
rm -rf .git

# 安装依赖
pip install --no-cache-dir -r requirements.txt
pip install --no-cache-dir -r manager_requirements.txt

# 清理无用文件
sh /os_clean.sh
