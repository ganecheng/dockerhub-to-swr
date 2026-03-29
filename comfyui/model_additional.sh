#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 应用目录
cd /app

# 下载模型

apt-get update && apt-get install -y ffmpeg

# 清理无用文件
sh /os_clean.sh