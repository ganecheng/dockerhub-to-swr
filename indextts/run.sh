#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

cd /app

# 直接用 venv 的 python，不用 uv run（uv run 会重新同步环境，把 torch 装回来）
/app/.venv/bin/python tools/gpu_check.py

exec /app/.venv/bin/python webui.py --host 0.0.0.0 --port 7860
