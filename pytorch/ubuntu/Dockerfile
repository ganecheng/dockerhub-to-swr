FROM nvidia/cuda:13.0.2-cudnn-runtime-ubuntu24.04

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

COPY pytorch/ubuntu/os_init.sh /os_init.sh
COPY pytorch/ubuntu/os_clean.sh /os_clean.sh
COPY pytorch/install_pytorch.sh /install_pytorch.sh

# 设置时区
ENV TZ=Asia/Shanghai

# 设置全局命令
ENV PATH="$PATH:/root/.local/bin"

# 构建
RUN sh /os_init.sh
RUN sh /install_pytorch.sh

RUN rm -rf /os_init.sh /install_pytorch.sh /os_clean.sh
