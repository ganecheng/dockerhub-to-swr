# 组件成分

* pytorch/pytorch 官方镜像 (Ubuntu + Miniforge conda)
* CUDA 13.2 Runtime + cuDNN 9
* Python (基础镜像 conda 预装)
* PyTorch 2.13.0（基础镜像内置）
* torchvision 0.28 / torchcodec 0.16（官方 cu132 wheel）
* torchaudio 2.11（cu130 wheel）

# 说明

直接基于 pytorch 官方 runtime 镜像，torch 与 CUDA 库由基础镜像提供，
仅补装 torchvision / torchcodec / torchaudio 与常用工具。

torchaudio 2.11.0 未发布 cu132 wheel，从 cu130 索引 `--no-deps` 安装，
并注释掉 `_check_cuda_version` 避免 cu130/cu132 差异导致 RuntimeError。
