# 组件成分

* Ubuntu 26.04 LTS
* CUDA 13.3 Runtime + cuDNN
* Python 3 (系统默认)
* PyTorch 2.12（源码编译 wheel，仅 sm_120 / RTX 50 系 Blackwell）
* torchvision 0.27 / torchcodec 0.12 / torchaudio 2.11（官方 wheel）

# 构建流程

torch 不使用官方 fat binary wheel（内含 8-10 套 GPU 架构 kernel 并重复打包 CUDA 库，安装后约 3GB），
而是源码编译仅含 sm_120 的专用 wheel（约 1GB，动态链接基础镜像的 CUDA 库）。

## Phase 1: 编译并发布 wheel（每个 torch 版本只需一次）

手动触发 `pytorch-wheel` 工作流 (`.github/workflows/pytorch-wheel.yml`)：

1. `pytorch/Dockerfile.wheel` 在 CUDA devel 环境中源码编译（约 2-4 小时）
2. wheel 上传到 GitHub Release，tag 形如 `torch-v2.12.1-sm120`，Release 说明附 sha256

## Phase 2: 构建镜像（每周五定时）

`pytorch` 工作流 (`.github/workflows/pytorch.yml`)：

1. 按 `TORCH_RELEASE_TAG` 用 `gh release view` 解析 wheel 下载链接
2. `docker build --build-arg TORCH_WHEEL_URL=<链接>` 传入 `pytorch/Dockerfile`，在镜像内下载安装

## 升级 torch 版本

1. 手动触发 `pytorch-wheel` 工作流，输入新版本号（如 `2.12.2`），等待 Release 发布完成
2. 更新 `pytorch.yml` 中的 `TORCH_RELEASE_TAG`（如 `torch-v2.12.2-sm120`）及 torchvision 等配套版本

## 本地构建镜像

从 GitHub Release 页面复制 wheel 的下载链接后：

```bash
docker build -f pytorch/Dockerfile \
  --build-arg TORCH_WHEEL_URL="https://github.com/<owner>/<repo>/releases/download/torch-v2.12.1-sm120/torch-2.12.1-cpXXX-cpXXX-linux_x86_64.whl" \
  -t pytorch-sm120 .
```

> wheel 下载依赖 GitHub Release 的公开访问；仓库为私有时需自行处理鉴权。
