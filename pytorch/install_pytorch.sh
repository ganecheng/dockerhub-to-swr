#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 校验基镜像预置的 torch/torchvision/torchaudio 对当前 python 可见，失败快速暴露；
# torchaudio 导入即触发 CUDA 版本检查，可确认它与 torch 的 CUDA 主版本一致
python3 -c "import torch, torchvision, torchaudio; print(torch.__version__, torchvision.__version__, torchaudio.__version__)"

pip install --no-cache-dir \
    torchcodec==0.17.* \
    --index-url https://download.pytorch.org/whl/cu132

# 校验 torchcodec 能否真正加载：缺 ffmpeg 时导入不会报错，必须断言探测成功
python3 -c "import torchcodec; print(torchcodec.__version__, 'ffmpeg' + str(torchcodec.ffmpeg_major_version)); assert torchcodec.ffmpeg_major_version, 'torchcodec 未能加载 ffmpeg'"

# 清理无用文件
sh /os_clean.sh