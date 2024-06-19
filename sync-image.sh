#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行; -x把将要运行的命令用一个 + 标记之后显示出来
set -ex

# docker pull
# 如果需要特定架构镜像可以手动指定  --platform linux/arm64 , linux/amd64 , linux/arm/v7 等信息

# 不指定 cpu 架构
cat trigger.txt | awk '{print "docker pull " $1} '
cat trigger.txt | awk '{print "docker pull " $1} ' | sh

#指定 cpu 架构
# cat trigger.txt | awk '{print "docker pull --platform linux/arm64 " $1} '
# cat trigger.txt | awk '{print "docker pull --platform linux/arm64 " $1} '| sh

# docker tag
cat trigger.txt | awk '{print "docker tag " $1 " swr.cn-south-1.myhuaweicloud.com/gsc-hub/" $1} '
cat trigger.txt | awk '{print "docker tag " $1 " swr.cn-south-1.myhuaweicloud.com/gsc-hub/" $1} ' | sh

# docker push
cat trigger.txt | awk '{print "docker push swr.cn-south-1.myhuaweicloud.com/gsc-hub/" $1} '
cat trigger.txt | awk '{print "docker push swr.cn-south-1.myhuaweicloud.com/gsc-hub/" $1} ' | sh
