#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 应用目录
cd /app

# 下载代码
git clone https://github.com/index-tts/index-tts.git . && git checkout 1d5d079
git lfs install
git lfs pull

git lfs uninstall && rm -rf .git

# 语言修改为默认中文
sed -i 's/.*getdefaultlocale.*/            language =\"zh_CN\"/' tools/i18n/i18n.py

# 增加OpenAI兼容TTS接口
sed -i '/__main__/,$d' webui.py
cat /restapi.py >> webui.py

# 使用uv安装依赖
pip install -U uv --no-cache-dir
uv sync --extra webui --no-cache

# 模型工具
uv tool install "huggingface-hub[cli,hf_xet]"
uv tool install "modelscope"

# 清理无用文件
sh /os_clean.sh