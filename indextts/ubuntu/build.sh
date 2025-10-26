#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 应用目录
mkdir -pv /app
cd /app

# 软件安装
apt-get update && apt-get install -y git git-lfs net-tools tree curl wget python3 python3-pip

# 下载代码
git clone https://github.com/index-tts/index-tts.git . && git checkout bde7d0b
git lfs install
git lfs pull

# 语言修改为默认中文
sed -i 's/.*getdefaultlocale.*/            language =\"zh_CN\"/' tools/i18n/i18n.py

# 使用uv安装依赖
pip install -U uv --no-cache-dir
uv sync --all-extras --no-cache

# 下载模型
uv tool install "huggingface-hub[cli,hf_xet]"
uv tool install "modelscope"
hf download IndexTeam/IndexTTS-2 --local-dir=checkpoints
hf download facebook/w2v-bert-2.0
hf download amphion/MaskGCT semantic_codec/model.safetensors
hf download funasr/campplus
hf download nvidia/bigvgan_v2_22khz_80band_256x bigvgan_generator.pt config.json
hf download Plachta/JDCnet bst.t7

# 启动命令
chmod 777 /run.sh

# 清理无用文件
apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
uv cache clean
git lfs uninstall && rm -rf .git
rm -rf /app/checkpoints/.cache /root/.cache/huggingface/xet /opt/conda
apt-get remove -y git git-lfs && apt-get autoremove -y
