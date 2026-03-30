FROM ghcr.io/ganecheng/pytorch:20260330_153327-ubuntu-x86_64

COPY comfyui/ubuntu/os_init.sh /os_init.sh
COPY comfyui/ubuntu/os_clean.sh /os_clean.sh

COPY comfyui/run.sh /run.sh
COPY comfyui/code.sh /code.sh
COPY comfyui/model_additional.sh /model_additional.sh

# 构建
RUN sh /os_init.sh
RUN sh /code.sh
RUN sh /model_additional.sh

USER root
VOLUME /root
WORKDIR /root
EXPOSE 8188
ENV CLI_ARGS=""

# 运行
CMD ["/run.sh"]
