#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 应用目录
cd /app

# 下载代码
git clone --filter=blob:none --no-checkout https://github.com/index-tts/index-tts.git .
git lfs install
git checkout v2.5.0
git lfs pull

git lfs uninstall && rm -rf .git

# 语言修改为默认中文
sed -i 's/.*getdefaultlocale.*/            language =\"zh_CN\"/' tools/i18n/i18n.py

# 移除pyproject.toml中基础镜像已提供的torch/torchaudio依赖
sed -i '/"torch==/d; /"torchaudio==/d' pyproject.toml

# 移除 [tool.uv.sources] 及之后所有内容（pytorch-cuda源配置，已不需要）
sed -i '/^\[tool\.uv\.sources\]/,$d' pyproject.toml

# 删除 uv.lock，防止锁定的传递依赖（如torch）被强制安装
rm -f uv.lock

# 创建可访问系统包的虚拟环境，复用基础镜像已有的PyTorch
uv venv --system-site-packages

# 使用uv安装依赖
uv sync --extra webui --no-cache

# 卸载uv安装的torch/torchaudio/nvidia-*，让虚拟环境复用系统site-packages中的PyTorch
uv pip uninstall torch torchaudio nvidia-cublas-cu12 nvidia-cuda-cupti-cu12 \
  nvidia-cuda-nvrtc-cu12 nvidia-cuda-runtime-cu12 nvidia-cudnn-cu12 \
  nvidia-cufft-cu12 nvidia-cufile-cu12 nvidia-curand-cu12 \
  nvidia-cusolver-cu12 nvidia-cusparse-cu12 nvidia-cusparselt-cu12 \
  nvidia-nccl-cu12 nvidia-nvjitlink-cu12 nvidia-nvtx-cu12 triton --yes 2>/dev/null || true

# === 诊断：打印依赖来源，方便出错时确认问题边界 ===
echo "=== uv 管理的虚拟环境依赖 ==="
uv pip list
echo ""
echo "=== 系统 site-packages 中的 PyTorch 相关包 ==="
python -c "
import sys; sys.path = [p for p in sys.path if '.venv' not in p]
import subprocess; subprocess.run([sys.executable, '-m', 'pip', 'list', '--format=freeze'])
" 2>/dev/null || python -m pip list --format=freeze 2>/dev/null || true
echo ""
echo "=== 运行时实际解析的 torch 来源 ==="
python -c "import torch; print(f'torch={torch.__version__}  from {torch.__file__}')" 2>/dev/null || echo "torch 导入失败!"
python -c "import torchaudio; print(f'torchaudio={torchaudio.__version__}  from {torchaudio.__file__}')" 2>/dev/null || echo "torchaudio 导入失败!"
python -c "import triton; print(f'triton={triton.__version__}  from {triton.__file__}')" 2>/dev/null || echo "triton 导入失败!"
echo "=== 诊断结束 ==="

# 清理无用文件
sh /os_clean.sh