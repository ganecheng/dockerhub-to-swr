#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 启动命令
chmod 777 /run.sh

# 应用目录
mkdir -pv /app

# 清理无用文件
sh /os_clean.sh