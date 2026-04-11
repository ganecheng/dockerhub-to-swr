FROM ubuntu:noble-20260324

# 忽略 PEP 668 的安全检查
ENV PIP_BREAK_SYSTEM_PACKAGES=1
# 设置环境变量，防止 Python 生成 .pyc 文件，缓冲输出以便实时查看日志
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY ace-step/ubuntu/os_init.sh /os_init.sh
COPY ace-step/ubuntu/os_clean.sh /os_clean.sh

COPY ace-step/run.sh /run.sh
COPY ace-step/code.sh /code.sh
COPY ace-step/model_additional.sh /model_additional.sh

# 设置时区
ENV TZ=Asia/Shanghai

# 设置全局命令
ENV PATH="$PATH:/root/.local/bin"

# 构建
RUN sh /os_init.sh
RUN sh /code.sh
RUN sh /model_additional.sh

USER root
VOLUME /root
WORKDIR /root
EXPOSE 7860
ENV CLI_ARGS=""

ENV LANGUAGE="zh"
ENV PORT="7860"
ENV SERVER_NAME="0.0.0.0"
ENV CHECK_UPDATE="false"
ENV CONFIG_PATH="--config_path acestep-v15-turbo"
ENV LM_MODEL_PATH="--lm_model_path acestep-5Hz-lm-4B"
ENV DOWNLOAD_SOURCE="--download-source huggingface"
ENV INIT_LLM="--init_llm auto"
ENV INIT_SERVICE="--init_service false"
ENV OFFLOAD_TO_CPU="--offload_to_cpu auto"
ENV ACESTEP_CHECKPOINTS_DIR="~/ace-step-models"

# 运行
CMD ["/run.sh"]
