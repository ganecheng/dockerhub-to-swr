# 基于PyTorch官方镜像
FROM pytorch/pytorch:2.8.0-cuda12.9-cudnn9-runtime

COPY index-tts-2/run.sh /run.sh
COPY index-tts-2/build.sh /build.sh

# 设置时区
ENV TZ=Asia/Shanghai

ENV PATH="$PATH:/root/.local/bin"

# 构建
RUN sh /build.sh

# 运行
CMD ["/run.sh"]
