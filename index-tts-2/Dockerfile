FROM ubuntu:jammy-20251001

COPY index-tts-2/run.sh /run.sh
COPY index-tts-2/build.sh /build.sh

# 设置时区
ENV TZ=Asia/Shanghai

# 设置全局命令
ENV PATH="$PATH:/root/.local/bin"

# 构建
RUN sh /build.sh

# 运行
CMD ["/run.sh"]
