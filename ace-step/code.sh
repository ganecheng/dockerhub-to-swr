#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 应用目录
mkdir -pv /app
cd /app

# 下载代码
git init .
git remote add origin https://github.com/ACE-Step/ACE-Step-1.5.git
git fetch --depth 1 origin 82252c2
git checkout FETCH_HEAD
rm -rf .git

# 安装依赖
uv sync

# 清理无用文件
sh /os_clean.sh
