---
name: 同步镜像模板aarch64
about: 用这个模板来同步镜像aarch64
title: ''
labels: aarch64, sync-image
assignees: ''

---

# ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑

在issue标题上填写需要同步的镜像名称，多个用英文逗号隔开，如下：

rancher/klipper-helm:v0.8.3-build20240228,rancher/klipper-lb:v0.4.7

# 标签
sync-image：有此标签的issue才会根据标题同步镜像
x86_64：有此标签代表同步x86_64架构镜像
aarch64：有此标签代表同步aarch64架构镜像
sync-image-success：有此标签代表镜像已同步成功
sync-image-fail：有此标签代表镜像同步失败

# 参考示例：

https://github.com/ganecheng/dockerhub-to-swr/issues/1
