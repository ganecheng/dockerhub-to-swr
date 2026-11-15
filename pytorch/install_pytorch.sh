#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 校验 torch/torchvision 对当前 python 可见，失败快速暴露（避免后续 pip 拉取重复的 fat binary torch）
python3 -c "import torch, torchvision; print(torch.__version__, torchvision.__version__)"

pip install --no-cache-dir \
    torchcodec==0.17.* \
    --index-url https://download.pytorch.org/whl/cu132

pip install --no-cache-dir --no-deps \
    torchaudio==2.11.* \
    --index-url https://download.pytorch.org/whl/cu134

# 校验两个补装的库能否真正加载：torchaudio 导入即触发 CUDA 版本检查，
# torchcodec 导入不会因缺 ffmpeg 报错，必须断言探测到 ffmpeg 才算可用
python3 -c "import torchaudio, torchcodec; print(torchaudio.__version__, torchcodec.__version__, 'ffmpeg' + str(torchcodec.ffmpeg_major_version)); assert torchcodec.ffmpeg_major_version, 'torchcodec 未能加载 ffmpeg'"

# 清理无用文件
sh /os_clean.sh