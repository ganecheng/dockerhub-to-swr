#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 应用目录
cd /app
source .venv/bin/activate

# 下载 SenseVoice 模型
modelscope download --model iic/SenseVoiceSmall --local_dir ./models/iic/SenseVoiceSmall

# 下载 VAD 模型（可选，用于长音频处理）
modelscope download --model iic/speech_fsmn_vad_zh-cn-16k-common-pytorch --local_dir ./models/iic/speech_fsmn_vad_zh-cn-16k-common-pytorch

# 清理无用文件
sh /os_clean.sh
