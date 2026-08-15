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

# 移除pyproject.toml中基础镜像已提供的torch/torchaudio依赖
sed -i '/"torch==/d; /"torchaudio==/d' pyproject.toml

# 移除 [tool.uv.sources] 及之后所有内容（pytorch-cuda源配置，已不需要）
sed -i '/^\[tool\.uv\.sources\]/,$d' pyproject.toml

# 创建可访问系统包的虚拟环境，复用基础镜像已有的PyTorch
uv venv --system-site-packages

# 使用uv安装依赖
uv sync --extra webui --no-cache

# 清理无用文件
sh /os_clean.sh