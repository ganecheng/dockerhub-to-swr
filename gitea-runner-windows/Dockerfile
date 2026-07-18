# escape=`

# 基础镜像：windows-dev (Windows Server Core + VS Build Tools + Git + NuGet)
# 补充 Node.js + Gitea Runner
FROM ghcr.io/ganecheng/windows-dev:20260614_200825-windows-x86_64

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG GITEA_RUNNER_VERSION=1.0.8
ARG NODE_VERSION=24.18.0

# 安装 Node.js（GitHub Actions 运行时依赖）
# 基础镜像已包含 Git、VS Build Tools、NuGet，无需重复安装
# 注意：需要变量展开的字符串必须使用 \"...\" 转义双引号，
# 否则 Docker SHELL 形式调用 powershell 会剥离双引号，
# 导致 PowerShell 将 ${env:PATH};C:\node 中的 ';' 误解析为语句分隔符
RUN $nodeDir = \"node-v${env:NODE_VERSION}-win-x64\"; `
    $url = \"https://nodejs.org/dist/v${env:NODE_VERSION}/${nodeDir}.zip\"; `
    Invoke-WebRequest -Uri $url -OutFile C:\node.zip; `
    Expand-Archive -Path C:\node.zip -DestinationPath C:\ -Force; `
    Rename-Item \"C:\${nodeDir}\" 'node' -Force; `
    Remove-Item C:\node.zip -Force; `
    [Environment]::SetEnvironmentVariable('PATH', \"${env:PATH};C:\node\", 'Machine'); `
    $env:PATH += ';C:\node'; `
    node --version; `
    npm --version

# 下载并安装 Gitea Runner
RUN New-Item -ItemType Directory -Path 'C:\opt\bin' -Force | Out-Null; `
    $url = \"https://gitea.com/gitea/runner/releases/download/v${env:GITEA_RUNNER_VERSION}/gitea-runner-${env:GITEA_RUNNER_VERSION}-windows-amd64.exe\"; `
    Invoke-WebRequest -Uri $url -OutFile 'C:\opt\bin\gitea-runner.exe'; `
    [Environment]::SetEnvironmentVariable('PATH', \"${env:PATH};C:\opt\bin\", 'Machine'); `
    $env:PATH += ';C:\opt\bin'; `
    gitea-runner --version

# 默认环境变量：均可在 docker run 时覆盖
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

# 复制启动脚本和配置模板到镜像
# 基础镜像 windows-dev 提供完整版 Git for Windows（含 Git Bash），
# 在此用于执行 run.sh 替代原 PowerShell 入口脚本
COPY gitea-runner-windows/run.sh C:/opt/run.sh
COPY gitea-runner-windows/config.template.yaml C:/opt/config.template.yaml

# Runner 数据卷（注册令牌、配置等）
VOLUME C:/data

# 默认启动命令：通过 Git Bash 执行 run.sh
CMD ["C:\\Program Files\\Git\\bin\\bash.exe", "/c/opt/run.sh"]
