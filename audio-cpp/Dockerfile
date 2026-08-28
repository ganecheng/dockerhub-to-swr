ARG UBUNTU_VERSION=24.04
ARG APP_VERSION=latest
ARG BUILD_DATE=N/A
ARG APP_REVISION=N/A
ARG IMAGE_URL=N/A
ARG IMAGE_SOURCE=N/A

FROM docker.io/ubuntu:${UBUNTU_VERSION} AS base

ARG APP_VERSION=latest
ARG BUILD_DATE
ARG APP_REVISION
ARG IMAGE_URL
ARG IMAGE_SOURCE

LABEL org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.version=$APP_VERSION \
      org.opencontainers.image.revision=$APP_REVISION \
      org.opencontainers.image.title="audio.cpp" \
      org.opencontainers.image.description="An all-in-one, pure C++ inference engine for audio models, powered by ggml (Vulkan, prebuilt)" \
      org.opencontainers.image.url=$IMAGE_URL \
      org.opencontainers.image.source=$IMAGE_SOURCE

# Runtime deps:
# - libgomp1: OpenMP threading
# - curl: healthcheck + GitHub release download
# - ffmpeg: audio I/O
# - python3: model installer
# - libvulkan1: Vulkan loader
# - mesa-vulkan-drivers: Mesa Vulkan ICDs (RADV for AMD, ANV for Intel)
# - ca-certificates: TLS for GitHub downloads
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libgomp1 curl ffmpeg python3 ca-certificates \
        libvulkan1 mesa-vulkan-drivers && \
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /tmp/* /var/tmp/* && \
    find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete && \
    find /var/cache -type f -delete

WORKDIR /app

# Download prebuilt Vulkan binaries from GitHub Release.
# APP_VERSION=latest follows the most recent release tag; any other value
# is treated as a pinned tag (e.g. v0.5.0 or 0.5.0 — "v" is added if missing).
ARG APP_VERSION=latest
ARG GITHUB_REPO=0xShug0/audio.cpp
RUN if [ "$APP_VERSION" = "latest" ]; then \
        TAG=$(curl -fsSL -o /dev/null -w '%{redirect_url}' \
            "https://github.com/${GITHUB_REPO}/releases/latest" | \
            sed 's|.*/tag/||'); \
    else \
        TAG="$APP_VERSION"; \
        case "$TAG" in v*) ;; *) TAG="v${TAG}" ;; esac; \
    fi && \
    URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/audio-${TAG}-bin-ubuntu-x64-vulkan.tar.gz" && \
    echo "Downloading ${URL}" && \
    curl -fsSL "$URL" -o /tmp/audio-vulkan.tar.gz && \
    tar -xzf /tmp/audio-vulkan.tar.gz -C /app && \
    rm /tmp/audio-vulkan.tar.gz

COPY .devops/entrypoint-vulkan.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

RUN mkdir -p /app/models && chown ubuntu:ubuntu /app/models

USER ubuntu

ENTRYPOINT ["/app/entrypoint.sh"]