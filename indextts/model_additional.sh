#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 应用目录
cd /app

# 下载模型
hf download facebook/w2v-bert-2.0
hf download amphion/MaskGCT semantic_codec/model.safetensors
hf download funasr/campplus
hf download nvidia/bigvgan_v2_22khz_80band_256x bigvgan_generator.pt config.json
hf download Plachta/JDCnet bst.t7

# 清理无用文件
sh /os_clean.sh