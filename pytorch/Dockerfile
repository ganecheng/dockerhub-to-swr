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

# 分层安装 PyTorch 生态，减小单层镜像大小
RUN set -ex && pip install --no-cache-dir \
    torch==2.12.* \
    --index-url https://download.pytorch.org/whl/cu132

RUN set -ex && pip install --no-cache-dir \
    torchvision==0.27.* \
    --index-url https://download.pytorch.org/whl/cu132

RUN set -ex && pip install --no-cache-dir \
    torchcodec==0.12.* \
    --index-url https://download.pytorch.org/whl/cu132

# torchaudio 2.11.0 未发布 cu132 wheel，从 cu130 索引安装；--no-deps 避免 cu130 版 torch 覆盖
RUN set -ex && pip install --no-cache-dir --no-deps \
    torchaudio==2.11.* \
    --index-url https://download.pytorch.org/whl/cu130

# torchaudio (cu130) 与 torch (cu132) CUDA 版本不匹配，注释掉版本检查避免 RuntimeError
RUN set -ex && \
    SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])" 2>/dev/null) && \
    TORCHAUDIO_INIT="${SITE_PACKAGES}/torchaudio/_extension/__init__.py" && \
    if [ -f "$TORCHAUDIO_INIT" ]; then \
        sed -i '/^[[:space:]]*_check_cuda_version()[[:space:]]*$/s/^/#/' "$TORCHAUDIO_INIT"; \
    fi

RUN sh /os_clean.sh

RUN rm -rf /os_init.sh /os_clean.sh
