#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

echo "[INFO] Starting ComfyUI..."
echo "########################################"

# Let .pyc files be stored in one place
export PYTHONPYCACHEPREFIX="/root/.cache/pycache"
# Let PIP install packages to /root/.local
export PIP_USER=true
# Add above to PATH
export PATH="${PATH}:/root/.local/bin"
# Suppress [WARNING: Running pip as the 'root' user]
export PIP_ROOT_USER_ACTION=ignore

cd /app

python -V

python main.py --listen 0.0.0.0 --port 8188 --enable-manager ${CLI_ARGS}