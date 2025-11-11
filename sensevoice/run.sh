#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

cd /app

source .venv/bin/activate

python -V

python webui.py
