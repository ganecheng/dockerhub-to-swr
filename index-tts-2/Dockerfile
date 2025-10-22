# 基于PyTorch官方镜像
FROM pytorch/pytorch:2.8.0-cuda12.9-cudnn9-runtime

# 设置时区
ENV TZ=Asia/Shanghai

# 软件安装
RUN apt-get update && apt-get install -y git git-lfs net-tools tree curl wget

# 下载代码
WORKDIR /app
RUN git clone https://github.com/index-tts/index-tts.git .
RUN git lfs install
RUN git lfs pull

# 使用uv安装依赖
RUN pip install -U uv --no-cache-dir
ENV PATH="$PATH:/root/.local/bin"
RUN uv sync --all-extras --no-cache

# 下载模型
RUN uv tool install "huggingface-hub[cli,hf_xet]"
RUN uv tool install "modelscope"
RUN hf download IndexTeam/IndexTTS-2 --local-dir=checkpoints
RUN hf download facebook/w2v-bert-2.0
RUN hf download amphion/MaskGCT semantic_codec/model.safetensors
RUN hf download funasr/campplus
RUN hf download nvidia/bigvgan_v2_22khz_80band_256x bigvgan_generator.pt config.json
RUN hf download Plachta/JDCnet bst.t7

# 启动命令
COPY index-tts-2/run.sh /app/run.sh
RUN chmod 777 /app/run.sh

# 清理无用文件
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN uv cache clean
RUN git lfs uninstall && rm -rf .git
RUN rm -rf /app/checkpoints/.cache
RUN apt-get remove -y git git-lfs && apt-get autoremove -y

# 运行
CMD ["/app/run.sh"]
