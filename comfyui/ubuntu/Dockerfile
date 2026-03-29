FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

# 忽略 PEP 668 的安全检查
ENV PIP_BREAK_SYSTEM_PACKAGES=1
# 设置环境变量，防止 Python 生成 .pyc 文件，缓冲输出以便实时查看日志
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY comfyui/ubuntu/os_init.sh /os_init.sh
COPY comfyui/ubuntu/os_clean.sh /os_clean.sh

COPY comfyui/run.sh /run.sh
COPY comfyui/code.sh /code.sh
COPY comfyui/model_additional.sh /model_additional.sh

# 设置时区
ENV TZ=Asia/Shanghai

# 设置全局命令
ENV PATH="$PATH:/root/.local/bin"

# 构建
RUN sh /os_init.sh
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cu128
RUN pip install --no-cache-dir torchvision --index-url https://download.pytorch.org/whl/cu128
RUN pip install --no-cache-dir torchaudio --index-url https://download.pytorch.org/whl/cu128
RUN sh /code.sh
RUN sh /model_additional.sh

# 运行
CMD ["/run.sh"]
