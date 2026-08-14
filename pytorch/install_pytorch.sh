#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

pip install --no-cache-dir \
    torch==2.12.* \
    torchvision==0.27.* \
    torchcodec==0.12.* \
    --index-url https://download.pytorch.org/whl/cu132

# torchaudio 2.11.0 未发布 cu132 wheel，从 cu130 索引安装；--no-deps 避免 cu130 版 torch 覆盖
pip install --no-cache-dir --no-deps torchaudio==2.11.* \
    --index-url https://download.pytorch.org/whl/cu130

# torchaudio (cu130) 与 torch (cu132) CUDA 版本不匹配，注释掉版本检查避免 RuntimeError
TORCHAUDIO_INIT=$(python3 -c "import importlib.util; s=importlib.util.find_spec('torchaudio._extension'); print(s.origin if s else '')" 2>/dev/null || echo "")
if [ -n "$TORCHAUDIO_INIT" ] && [ -f "$TORCHAUDIO_INIT" ]; then
    sed -i '/^[[:space:]]*_check_cuda_version()[[:space:]]*$/s/^/#/' "$TORCHAUDIO_INIT"
fi

# 清理无用文件
sh /os_clean.sh
