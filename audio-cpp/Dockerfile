# 基础镜像：Ubuntu 26.04 (resolute)
FROM ghcr.io/ganecheng/ubuntu:20260829_031258-x86_64

# 构建参数：audio.cpp 版本号（latest 跟随最新 release，其他值视为固定 tag）
ARG APP_VERSION=v0.7.0

# 安装运行时依赖并下载 audio.cpp 预编译 Vulkan 二进制文件
RUN <<EOF
  # 封装 curl：统一超时和重试策略
  function curl() {
    command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
  }

  # 安装 audio.cpp 运行时依赖
  # - libgomp1: OpenMP 线程支持
  # - ffmpeg: 音频 I/O
  # - libvulkan1: Vulkan 加载器
  # - mesa-vulkan-drivers: Mesa Vulkan ICD（RADV for AMD, ANV for Intel）
  apt-get update
  apt-get install -y --no-install-recommends \
    libgomp1 ffmpeg libvulkan1 mesa-vulkan-drivers

  # 解析 release tag（latest 跟随最新 release，其他值自动补 "v" 前缀）
  GITHUB_REPO="0xShug0/audio.cpp"
  if [ "$APP_VERSION" = "latest" ]; then
    TAG=$(curl -o /dev/null -w '%{redirect_url}' \
        "https://github.com/${GITHUB_REPO}/releases/latest" | \
        sed 's|.*/tag/||')
  else
    TAG="$APP_VERSION"
    case "$TAG" in v*) ;; *) TAG="v${TAG}" ;; esac
  fi

  # 下载并解压预编译 Vulkan 二进制文件
  audio_url="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/audio-${TAG}-bin-ubuntu-x64-vulkan.tar.gz"
  echo "Downloading audio.cpp from $audio_url"
  curl "$audio_url" -o /tmp/audio-vulkan.tar.gz
  install -d -m 0755 /app
  tar -xzf /tmp/audio-vulkan.tar.gz -C /app
  rm -f /tmp/audio-vulkan.tar.gz

  # 赋予二进制文件可执行权限
  chmod +x /app/audiocpp_cli /app/audiocpp_server /app/audiocpp_gguf

  # 创建模型目录
  install -d -m 0755 /app/models

  # 清理缓存和临时文件，减小镜像体积
  rm -rf /var/cache/{apt,debconf} /var/lib/apt/lists/* /var/log/{apt,alternatives.log,bootstrap.log,dpkg.log} /tmp/* /var/tmp/*

EOF

# 默认环境变量：均可在 docker run 时覆盖
ENV CA_CERT_DIR='/opt/cloud/security/cert/ca'
ENV AUDIO_CPP_COMMAND='server'
ENV AUDIO_CPP_ARGS=''

WORKDIR /app

# 复制启动脚本到镜像
COPY audio-cpp/run.sh /opt/

# audio.cpp server 默认监听端口
EXPOSE 8080/tcp

# 默认启动命令
CMD ["/bin/bash", "/opt/run.sh"]
