FROM openeuler/openeuler:24.03-lts-sp2

COPY sensevoice/openeuler/os_init.sh /os_init.sh
COPY sensevoice/openeuler/os_clean.sh /os_clean.sh

COPY sensevoice/run.sh /run.sh
COPY sensevoice/code.sh /code.sh
COPY sensevoice/model.sh /model.sh
COPY sensevoice/webui.py /webui.py

# 设置时区
ENV TZ=Asia/Shanghai

# 设置全局命令
ENV PATH="$PATH:/root/.local/bin"

# 构建
RUN sh /os_init.sh
RUN sh /code.sh
RUN sh /model.sh

# 运行
CMD ["/run.sh"]
