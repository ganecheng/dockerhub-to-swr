# escape=`

# 基于 windows（Windows Server Core + VS Build Tools + Git + NuGet）追加 Node.js + Gitea Runner
FROM ghcr.io/ganecheng/windows:20260719_222451-x86_64

ENV GITEA_RUNNER_VERSION=1.0.8 `
    NODE_VERSION=24.18.0

# 安装目录
ENV NODE_HOME="C:\Program Files\nodejs" `
    GITEA_RUNNER_HOME="C:\opt\bin"

# 追加 Node.js 和 Gitea Runner 到系统 PATH
RUN [Environment]::SetEnvironmentVariable('PATH', \"${env:PATH};${env:NODE_HOME};${env:GITEA_RUNNER_HOME}\", 'Machine')

# 模块化安装脚本（Git Bash 版）
COPY gitea-runner-windows/modules/common.sh gitea-runner-windows/modules/setup.sh C:/tmp/

# Git Bash 执行安装脚本（ENV 变量直接传递给 bash）
RUN bash /c/tmp/setup.sh; Remove-Item -Recurse -Force C:\tmp -ErrorAction SilentlyContinue

# 默认环境变量，运行时可覆盖
ENV `
    INIT_SH_FILE='' `
    CA_CERT_DIR='C:\certs' `
    NPM_REGISTRY='https://mirrors.huaweicloud.com/repository/npm/' `
    GITEA_RUNNER_CONFIG_TEMPLATE_FILE='C:\opt\config.template.yaml' `
    GITEA_RUNNER_NAME='' `
    GITEA_RUNNER_LABELS='' `
    GITEA_RUNNER_LABELS_DEFAULT='windows-latest,windows-2022' `
    GITEA_RUNNER_REGISTRATION_TIMEOUT=30 `
    GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL=3 `
    GITEA_RUNNER_TIMEOUT_MINUTES=60

# 入口脚本与配置模板
COPY gitea-runner-windows/run.sh C:/opt/run.sh
COPY gitea-runner-windows/config.template.yaml C:/opt/config.template.yaml

# Runner 数据卷
VOLUME C:/data

# Git Bash 执行 run.sh
CMD ["bash", "/c/opt/run.sh"]
