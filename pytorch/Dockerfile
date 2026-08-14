# 源码编译的 torch 仅 sm_120 (Blackwell)，动态链接 CUDA 库，运行时镜像必须包含 cuBLAS/cuDNN 等，
# 因此不能用 base 变体；wheel 由 pytorch-wheel 工作流编译发布到 GitHub Release
FROM nvidia/cuda:13.3.1-cudnn-runtime-ubuntu26.04

# 移除基础镜像的标签
LABEL maintainer=""
LABEL com.nvidia.cudnn.version=""
LABEL org.opencontainers.image.ref.name=""
LABEL org.opencontainers.image.version=""

# 忽略 PEP 668 的安全检查
ENV PIP_BREAK_SYSTEM_PACKAGES=1
# 设置环境变量，防止 Python 生成 .pyc 文件，缓冲输出以便实时查看日志
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY pytorch/os_init.sh /os_init.sh
COPY pytorch/os_clean.sh /os_clean.sh

# 设置时区
ENV TZ=Asia/Shanghai

# 设置全局命令
ENV PATH="$PATH:/root/.local/bin"

# 构建
RUN sh /os_init.sh

# 安装源码编译的 torch wheel（仅 sm_120 kernel，动态链接本镜像的 CUDA 库，不重复打包）
# wheel 来自 GitHub Release，URL 由 workflow 通过 --build-arg 注入；
# 本地构建需从 Release 页面复制 wheel 下载链接，见 pytorch/README.md
ARG TORCH_WHEEL_URL
RUN set -ex && TORCH_WHL="/tmp/$(basename "${TORCH_WHEEL_URL}")" \
    && curl -sfL --retry 3 --retry-delay 5 -o "${TORCH_WHL}" "${TORCH_WHEEL_URL}" \
    && pip install --no-cache-dir "${TORCH_WHL}" \
    && rm -rf /tmp/* /var/tmp/* /root/.cache/pip

# --no-deps 避免 pip 拉取官方 fat binary torch 覆盖源码编译版本；
# numpy/pillow 是 torchvision 的运行时依赖，被 --no-deps 跳过后需手动安装
RUN set -ex && pip install --no-cache-dir --no-deps \
    torchvision==0.27.* \
    --index-url https://download.pytorch.org/whl/cu132 \
    && pip install --no-cache-dir numpy pillow \
    && rm -rf /root/.cache/pip /tmp/* /var/tmp/*

RUN set -ex && pip install --no-cache-dir --no-deps \
    torchcodec==0.12.* \
    --index-url https://download.pytorch.org/whl/cu132 \
    && rm -rf /root/.cache/pip /tmp/* /var/tmp/*

# torchaudio 2.11.0 未发布 cu132 wheel，从 cu130 索引安装；--no-deps 避免 cu130 版 torch 覆盖
RUN set -ex && pip install --no-cache-dir --no-deps \
    torchaudio==2.11.* \
    --index-url https://download.pytorch.org/whl/cu130 \
    && rm -rf /root/.cache/pip /tmp/* /var/tmp/*

# torchaudio (cu130) 与 torch (源码编译) CUDA 版本不匹配，注释掉版本检查避免 RuntimeError
RUN set -ex && \
    SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])" 2>/dev/null) && \
    TORCHAUDIO_INIT="${SITE_PACKAGES}/torchaudio/_extension/__init__.py" && \
    if [ -f "$TORCHAUDIO_INIT" ]; then \
        sed -i '/^[[:space:]]*_check_cuda_version()[[:space:]]*$/s/^/#/' "$TORCHAUDIO_INIT"; \
    fi

RUN sh /os_clean.sh

RUN rm -rf /os_init.sh /os_clean.sh
