#!/bin/bash

set -ex

target_registry="swr.cn-southwest-2.myhuaweicloud.com"
target_repo="gsc-hub"

list="batch_sync_image_list.txt"
for i in $(cat ${list}); do
    skopeo copy docker://${i} docker://${target_registry}/${target_repo}/${i}
done
