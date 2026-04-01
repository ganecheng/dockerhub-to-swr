#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 软件安装
apt-get update && apt-get install -y vim git git-lfs net-tools tree curl wget python3 python3-pip ffmpeg

# 设置全局python命令
ln -s /usr/bin/python3 /usr/bin/python

# 使用uv安装依赖
pip install --no-cache-dir -U uv
# 模型工具
pip install --no-cache-dir "huggingface-hub[cli,hf_xet]"
pip install --no-cache-dir modelscope

# 常用命令自定义
cat >>/etc/bash.bashrc <<'EOF'

# 输入..并回车，即可返回到上一级目录
shopt -s autocd

reset_alias() {
    # 命名别名配置
    alias l="ls -alh"
    alias ll="ls -alh"
    alias lll="ls -alh"
}
PROMPT_COMMAND="reset_alias;$PROMPT_COMMAND"

EOF

# 清理无用文件
sh /os_clean.sh