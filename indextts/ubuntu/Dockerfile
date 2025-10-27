FROM ubuntu:jammy-20251001

COPY indextts/ubuntu/os_init.sh /os_init.sh
COPY indextts/ubuntu/os_clean.sh /os_clean.sh

COPY indextts/run.sh /run.sh
COPY indextts/code.sh /code.sh
COPY indextts/model_indextts.sh /model_indextts.sh
COPY indextts/model_additional.sh /model_additional.sh

# 设置时区
ENV TZ=Asia/Shanghai

# 设置全局命令
ENV PATH="$PATH:/root/.local/bin"

# 构建
RUN sh /os_init.sh
RUN sh /code.sh
RUN sh /model_indextts.sh
RUN sh /model_additional.sh

# 运行
CMD ["/run.sh"]
