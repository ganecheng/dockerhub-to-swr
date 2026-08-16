#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# CI 环境禁用进度条，避免刷屏
export HF_HUB_DISABLE_PROGRESS_BARS=1
export CI=true
export TERM=dumb

# 应用目录
cd /app

# 创建hf_cache目录（运行时模型缓存目录）
mkdir -p ./checkpoints/hf_cache

# 下载 w2v-bert-2.0（运行时使用modelscope下载，此处保持一致）
modelscope download --model AI-ModelScope/w2v-bert-2.0 --local_dir ./checkpoints/hf_cache/w2v-bert-2.0

# 下载 MaskGCT semantic codec（运行时保存为 semantic_codec_model.safetensors）
hf download amphion/MaskGCT semantic_codec/model.safetensors --local-dir ./checkpoints/hf_cache/
mv ./checkpoints/hf_cache/semantic_codec/model.safetensors ./checkpoints/hf_cache/semantic_codec_model.safetensors
rm -rf ./checkpoints/hf_cache/semantic_codec

# 下载 CAMPPlus（运行时保存为 campplus_cn_common.bin）
hf download funasr/campplus campplus_cn_common.bin --local-dir ./checkpoints/hf_cache/

# 下载 BigVGAN
hf download nvidia/bigvgan_v2_22khz_80band_256x bigvgan_generator.pt config.json --local-dir ./checkpoints/hf_cache/bigvgan/

# 下载 JDCnet
hf download Plachta/JDCnet bst.t7 --local-dir ./checkpoints/hf_cache/

# 预下载示例音频文件（避免启动时从 HuggingFace 下载）
mkdir -p ./examples
BASE_URL="https://huggingface.co/spaces/IndexTeam/IndexTTS-2-Demo/resolve/main/examples"
for f in voice_01.wav voice_02.wav voice_03.wav voice_04.wav voice_05.wav \
  voice_06.wav voice_07.wav voice_08.wav voice_09.wav voice_11.wav \
  voice_12.wav emo_hate.wav emo_sad.wav; do
  curl -sSL "${BASE_URL}/${f}" -o "./examples/${f}"
done

# 预构建 zh_normalizer FST 文件（首次构建耗时约 13 秒）
mkdir -p ./indextts/utils/tagger_cache
uv run python -c "from wetext import Normalizer; Normalizer(['zh']); print('zh_normalizer FST pre-built')"

# 清理无用文件
sh /os_clean.sh