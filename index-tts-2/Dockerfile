# 基于PyTorch官方镜像
FROM pytorch/pytorch:2.8.0-cuda12.9-cudnn9-runtime
RUN apt-get update && apt-get install -y \
    git \
    git-lfs \
    && rm -rf /var/lib/apt/lists/*

# 下载代码
WORKDIR /app
RUN git clone https://github.com/index-tts/index-tts.git .
RUN git lfs install
RUN git lfs pull

# 使用uv安装依赖
RUN pip install -U uv
ENV PATH $PATH:/root/.local/bin
RUN uv sync --all-extras

# 下载模型
RUN uv tool install "huggingface-hub[cli,hf_xet]"
RUN hf download IndexTeam/IndexTTS-2 --local-dir=checkpoints

# 启动命令
RUN echo "uv run webui.py --host 0.0.0.0 --port 7860 --fp16 --cuda_kernel" > run.sh
RUN chmod 777 run.sh

# 运行
CMD ["/app/run.sh"]
