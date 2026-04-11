#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

huggingface-cli download marcorez8/acestep-v15-xl-turbo-bf16 --local-dir /checkpoints/acestep-v15-xl-turbo-bf16

# 清理无用文件
sh /os_clean.sh