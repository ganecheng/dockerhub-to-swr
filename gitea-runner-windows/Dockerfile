# escape=`

# 基于 windows（Windows Server Core + VS Build Tools + Git + NuGet）追加 Node.js + Qwen Code + Gitea Runner
FROM ghcr.io/ganecheng/windows:20260918_195906-x86_64

ENV GITEA_RUNNER_VERSION=3.5.0 `
    NODE_VERSION=24.21.0 `
    QWEN_CODE_VERSION=0.24.3

# 安装目录
ENV NODE_HOME="C:\Program Files\nodejs" `
    NPM_GLOBAL_HOME="C:\opt\npm" `
    GITEA_RUNNER_HOME="C:\opt\bin"

# 追加 Node.js、npm 全局目录和 Gitea Runner 到系统 PATH
RUN [Environment]::SetEnvironmentVariable('PATH', \"${env:PATH};${env:NODE_HOME};${env:NPM_GLOBAL_HOME};${env:GITEA_RUNNER_HOME}\", 'Machine')

# 安装 Python 3（Chocolatey），供 job 内的 fmt_stream.py 使用
# choco/官方安装器的落地目录随版本变化，按候选路径定位 python.exe 并确保其目录在 PATH 上；
# 同时把 python.exe 复制为 python3.exe，以便直接复用 Linux 侧的 `python3 -u ...` 调用方式
RUN choco install python3 -y --no-progress; `
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine'); `
    $python = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source; `
    if (-not $python) { `
      $python = Get-ChildItem (Join-Path 'C:\' 'Python*\python.exe'), (Join-Path 'C:\Program Files' 'Python*\python.exe'), (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python*\python.exe') -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName `
    }; `
    if (-not $python) { throw 'python.exe not found after choco install' }; `
    $pythonDir = Split-Path $python -Parent; `
    Copy-Item (Join-Path $pythonDir 'python.exe') (Join-Path $pythonDir 'python3.exe') -Force; `
    $machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine'); `
    if ($machinePath -notlike ('*' + $pythonDir + '*')) { [Environment]::SetEnvironmentVariable('PATH', $machinePath + ';' + $pythonDir + ';' + (Join-Path $pythonDir 'Scripts'), 'Machine') }; `
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine'); `
    python --version; `
    python3 --version; `
    python -c 'import json, shutil, sys; print(sys.version_info[:3])'

# 模块化安装脚本（Git Bash 版）
COPY gitea-runner-windows/modules/common.sh gitea-runner-windows/modules/setup.sh C:/tmp/

# Git Bash 执行安装脚本（ENV 变量直接传递给 bash）
RUN bash /c/tmp/setup.sh; Remove-Item -Recurse -Force C:\tmp -ErrorAction SilentlyContinue

# 默认环境变量，运行时可覆盖
ENV `
    INIT_SH_FILE='' `
    CA_CERT_DIR='C:\certs' `
    NPM_REGISTRY='https://mirrors.huaweicloud.com/repository/npm/' `
    NODE_USE_SYSTEM_CA=1 `
    GITEA_RUNNER_CONFIG_TEMPLATE_FILE='C:\opt\config.template.yaml' `
    GITEA_RUNNER_NAME='' `
    GITEA_RUNNER_LABELS='' `
    GITEA_RUNNER_LABELS_DEFAULT='windows-latest,windows-2022' `
    GITEA_RUNNER_REGISTRATION_TIMEOUT=30 `
    GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL=3 `
    GITEA_RUNNER_TIMEOUT_MINUTES=60 `
    QWEN_CODE_SUPPRESS_YOLO_WARNING=1

# 入口脚本与配置模板
COPY gitea-runner-windows/run.sh C:/opt/run.sh
COPY gitea-runner-windows/config.template.yaml C:/opt/config.template.yaml

# qwen 流式输出格式化脚本（供 job 内 qwen 的 stream-json 输出使用）
# 与 Ubuntu 版 Runner 共用仓库内同一份脚本
COPY common/fmt_stream.py C:/opt/bin/fmt_stream.py

# Git Bash 执行 run.sh
CMD ["bash", "/c/opt/run.sh"]
