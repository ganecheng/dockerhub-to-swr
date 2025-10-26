FROM ubuntu:jammy-20251001

COPY indextts/ubuntu/run.sh /run.sh
COPY indextts/ubuntu/build.sh /build.sh

# 设置时区
ENV TZ=Asia/Shanghai

# 设置全局命令
ENV PATH="$PATH:/root/.local/bin"

# 构建
RUN sh /build.sh

# 运行
CMD ["/run.sh"]
