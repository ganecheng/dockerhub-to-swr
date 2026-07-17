# escape=`

# 基础镜像：windows-dev (Windows Server Core + VS Build Tools + Git + NuGet)
# 补充 Node.js + Gitea Runner，不含 Docker-in-Docker，任务以 host 模式运行
FROM ghcr.io/ganecheng/windows-dev:20260614_200825-windows-x86_64

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG GITEA_RUNNER_VERSION=1.0.8
ARG NODE_VERSION=24.18.0

# 安装 Node.js（GitHub Actions 运行时依赖）
# 基础镜像已包含 Git、VS Build Tools、NuGet，无需重复安装
RUN $nodeDir = "node-v${env:NODE_VERSION}-win-x64"; `
    $url = "https://nodejs.org/dist/v${env:NODE_VERSION}/${nodeDir}.zip"; `
    Invoke-WebRequest -Uri $url -OutFile C:\node.zip; `
    Expand-Archive -Path C:\node.zip -DestinationPath C:\ -Force; `
    Rename-Item "C:\${nodeDir}" 'node' -Force; `
    Remove-Item C:\node.zip -Force; `
    [Environment]::SetEnvironmentVariable('PATH', "${env:PATH};C:\node", 'Machine'); `
    $env:PATH += ';C:\node'; `
    node --version; `
    npm --version

# 下载并安装 Gitea Runner
RUN New-Item -ItemType Directory -Path 'C:\opt\bin' -Force | Out-Null; `
    $url = "https://gitea.com/gitea/runner/releases/download/v${env:GITEA_RUNNER_VERSION}/gitea-runner-${env:GITEA_RUNNER_VERSION}-windows-amd64.exe"; `
    Invoke-WebRequest -Uri $url -OutFile 'C:\opt\bin\gitea-runner.exe'; `
    [Environment]::SetEnvironmentVariable('PATH', "${env:PATH};C:\opt\bin", 'Machine'); `
    $env:PATH += ';C:\opt\bin'; `
    gitea-runner --version

# 默认环境变量：均可在 docker run 时覆盖
ENV `
    INIT_PS1_FILE='' `
    CA_CERT_DIR='C:\certs' `
    NPM_REGISTRY='https://mirrors.huaweicloud.com/repository/npm/' `
    GITEA_RUNNER_CONFIG_TEMPLATE_FILE='C:\opt\config.template.yaml' `
    GITEA_RUNNER_NAME='' `
    GITEA_RUNNER_LABELS='' `
    GITEA_RUNNER_LABELS_DEFAULT='windows-latest:host,windows-2022:host' `
    GITEA_RUNNER_REGISTRATION_TIMEOUT=30 `
    GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL=3 `
    GITEA_RUNNER_TIMEOUT_MINUTES=60

# 复制启动脚本和配置模板到镜像
COPY gitea-runner-windows/run.ps1 C:/opt/run.ps1
COPY gitea-runner-windows/config.template.yaml C:/opt/config.template.yaml

# Runner 数据卷（注册令牌、配置等）
VOLUME C:/data

# 默认启动命令
CMD ["powershell", "-ExecutionPolicy", "Bypass", "-File", "C:\\opt\\run.ps1"]
