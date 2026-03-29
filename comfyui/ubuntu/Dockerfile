FROM pytorch/pytorch:2.11.0-cuda13.0-cudnn9-runtime

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
RUN sh /code.sh
RUN sh /model_additional.sh

# 运行
CMD ["/run.sh"]
