FROM ghcr.io/ganecheng/pytorch:20260815_014227-x86_64

COPY indextts/os_init.sh /os_init.sh
COPY indextts/os_clean.sh /os_clean.sh

COPY indextts/run.sh /run.sh
COPY indextts/code.sh /code.sh
COPY indextts/model_indextts.sh /model_indextts.sh
COPY indextts/model_additional.sh /model_additional.sh

# 构建
RUN sh /os_init.sh
RUN sh /code.sh
RUN sh /model_indextts.sh
RUN sh /model_additional.sh

# 运行
CMD ["/run.sh"]
