#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 用镜像内的 ComfyUI 代码覆盖工作目录, 换新镜像即升级到 bundle 中的版本;
# 'cp --archive': all file timestamps and permissions will be preserved
# 以下目录不覆盖, 保留用户存量数据:
#   custom_nodes/  用户安装的自定义节点 (镜像自带的示例节点仍会补入)
#   user/          用户设置, 其中 user/default/workflows 为独立挂载点
#   models/ input/ output/  独立挂载的数据卷
cd /root
mkdir -p /root/ComfyUI
echo "[INFO] Syncing ComfyUI from image bundle to '/root/ComfyUI'..."

# 目录下每个条目逐个拷贝, 失败时由 set -e 中断启动 (find -exec 不会回传 cp 的退出码)
cd /default_comfyui_bundle/ComfyUI
for item in * .[!.]* ..?* ; do
    [ -e "$item" ] || continue
    case "$item" in
        custom_nodes|user|models|input|output) continue ;;
    esac
    cp --archive -- "$item" /root/ComfyUI/
done

# custom_nodes/ 只补入镜像自带示例, 已存在的文件 (含用户节点) 不动
mkdir -p /root/ComfyUI/custom_nodes
cp --archive --update=none "/default_comfyui_bundle/ComfyUI/custom_nodes/." "/root/ComfyUI/custom_nodes/"

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
