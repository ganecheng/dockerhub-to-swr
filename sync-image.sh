#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行; -x把将要运行的命令用一个 + 标记之后显示出来
set -ex

list="trigger.txt"
for i in $(cat ${list}); do
    docker pull ${i}
    docker tag ${i} swr.cn-south-1.myhuaweicloud.com/gsc-hub/${i}
    docker push swr.cn-south-1.myhuaweicloud.com/gsc-hub/${i}
    docker rmi ${i} swr.cn-south-1.myhuaweicloud.com/gsc-hub/${i}
done
