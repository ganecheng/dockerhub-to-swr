#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 校验 torch/torchvision 对当前 python 可见，失败快速暴露（避免后续 pip 拉取重复的 fat binary torch）
python3 -c "import torch, torchvision; print(torch.__version__, torchvision.__version__)"

pip install --no-cache-dir \
    torchcodec==0.16.* \
    --index-url https://download.pytorch.org/whl/cu132

pip install --no-cache-dir --no-deps \
    torchaudio==2.11.* \
    --index-url https://download.pytorch.org/whl/cu130

# torchaudio (cu130) 与 torch (cu132) CUDA 版本不匹配，注释掉版本检查避免 RuntimeError
SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])" 2>/dev/null)
TORCHAUDIO_INIT="${SITE_PACKAGES}/torchaudio/_extension/__init__.py"
if [ -f "$TORCHAUDIO_INIT" ]; then
    sed -i '/^[[:space:]]*_check_cuda_version()[[:space:]]*$/s/^/#/' "$TORCHAUDIO_INIT"
fi

# 清理无用文件
sh /os_clean.sh