# 基于PyTorch官方镜像
FROM pytorch/pytorch:2.8.0-cuda12.9-cudnn9-runtime

COPY index-tts-2/run.sh /app/run.sh
COPY index-tts-2/build.sh /app/build.sh

# 设置时区
ENV TZ=Asia/Shanghai

WORKDIR /app

ENV PATH="$PATH:/root/.local/bin"

# 构建
RUN sh /app/build.sh

# 运行
CMD ["/app/run.sh"]
