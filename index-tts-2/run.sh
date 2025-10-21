#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

source /root/.profile

python -V

uv run tools/gpu_check.py

uv run webui.py --host 0.0.0.0 --port 7860 --fp16 --cuda_kernel
