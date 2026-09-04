FROM pytorch/pytorch:2.14.0-cuda13.2-cudnn9-runtime

# 移除基础镜像的标签
LABEL maintainer=""
LABEL org.opencontainers.image.ref.name=""
LABEL org.opencontainers.image.version=""

# 忽略 PEP 668 的安全检查（基础镜像为 Ubuntu 24.04 系统 Python 3.12，externally-managed）
ENV PIP_BREAK_SYSTEM_PACKAGES=1
# 设置环境变量，防止 Python 生成 .pyc 文件，缓冲输出以便实时查看日志
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY pytorch/os_init.sh /os_init.sh
COPY pytorch/os_clean.sh /os_clean.sh
COPY pytorch/install_pytorch.sh /install_pytorch.sh

# 设置时区
ENV TZ=Asia/Shanghai

# 设置全局命令
ENV PATH="$PATH:/root/.local/bin"

RUN sh /os_init.sh
RUN sh /install_pytorch.sh

RUN rm -rf /os_init.sh /os_clean.sh /install_pytorch.sh
