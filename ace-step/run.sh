#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

cd /app

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

# Let .pyc files be stored in one place
export PYTHONPYCACHEPREFIX="/root/.cache/pycache"
# Add above to PATH
export PATH="${PATH}:/root/.local/bin"
# Suppress [WARNING: Running pip as the 'root' user]
export PIP_ROOT_USER_ACTION=ignore

python -V

# 首次使用需添加执行权限
chmod +x start_gradio_ui.sh

# 启动 Gradio 网页界面
./start_gradio_ui.sh
