#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# Copy ComfyUI from cache to workdir if it doesn't exist
cd /root
if [ ! -f "/root/ComfyUI/main.py" ] ; then
    mkdir -p /root/ComfyUI
    # 'cp --archive': all file timestamps and permissions will be preserved
    # 'cp --update=none': do not overwrite
    if cp --archive --update=none "/default_comfyui_bundle/ComfyUI/." "/root/ComfyUI/" ; then
        echo "[INFO] Setting up ComfyUI..."
        echo "[INFO] Using image-bundled ComfyUI (copied to workdir)."
    else
        echo "[ERROR] Failed to copy ComfyUI bundle to '/root/ComfyUI'" >&2
        exit 1
    fi
else
    echo "[INFO] Using existing ComfyUI in user storage..."
fi

# 设置国内pip仓库镜像站, pip安装依赖到/root目录下
if [ ! -f "/root/.config/pip/pip.conf" ] ; then
    echo "[INFO] 设置国内pip仓库镜像站, pip安装依赖到/root目录下"
    mkdir -p /root/.config/pip/

    # 常用命令自定义
    cat >>/root/.config/pip/pip.conf <<'EOF'
[global]
index = https://mirrors.huaweicloud.com/repository/pypi
index-url = https://mirrors.huaweicloud.com/repository/pypi/simple
trusted-host = mirrors.huaweicloud.com
user = true
EOF

else
    echo "[INFO] Using existing /root/.config/pip/pip.conf in user storage..."
fi

echo "[INFO] Starting ComfyUI..."
echo "########################################"

# Let .pyc files be stored in one place
export PYTHONPYCACHEPREFIX="/root/.cache/pycache"
# Add above to PATH
export PATH="${PATH}:/root/.local/bin"
# Suppress [WARNING: Running pip as the 'root' user]
export PIP_ROOT_USER_ACTION=ignore

python -V

python /root/ComfyUI/main.py --listen 0.0.0.0 --port 8188 --enable-manager --enable-manager-legacy-ui ${CLI_ARGS}
