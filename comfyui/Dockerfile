FROM ghcr.io/ganecheng/pytorch:20260724_174219-ubuntu-x86_64

COPY comfyui/os_init.sh /os_init.sh
COPY comfyui/os_clean.sh /os_clean.sh

COPY comfyui/run.sh /run.sh
COPY comfyui/code.sh /code.sh
COPY comfyui/model_additional.sh /model_additional.sh

# 构建
RUN sh /os_init.sh
RUN sh /code.sh
RUN sh /model_additional.sh

USER root
WORKDIR /root
EXPOSE 8188
ENV CLI_ARGS=""

# 运行
CMD ["/run.sh"]
