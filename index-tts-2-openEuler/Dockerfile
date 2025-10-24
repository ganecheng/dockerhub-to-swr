FROM openeuler/openeuler:24.03-lts-sp2

COPY index-tts-2-openEuler/run.sh /run.sh
COPY index-tts-2-openEuler/build.sh /build.sh

# 设置时区
ENV TZ=Asia/Shanghai

# 设置全局命令
ENV PATH="$PATH:/root/.local/bin"

# 构建
RUN sh /build.sh

# 运行
CMD ["/run.sh"]
