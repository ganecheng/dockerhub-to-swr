FROM ghcr.io/ganecheng/ubuntu:20260723_142929-x86_64

COPY sensevoice/os_init.sh /os_init.sh
COPY sensevoice/os_clean.sh /os_clean.sh

COPY sensevoice/run.sh /run.sh
COPY sensevoice/code.sh /code.sh
COPY sensevoice/model.sh /model.sh
COPY sensevoice/webui.py /webui.py

# 构建
RUN sh /os_init.sh
RUN sh /code.sh
RUN sh /model.sh

# 运行
CMD ["/run.sh"]
