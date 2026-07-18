# run.ps1 - Gitea Runner Windows 启动脚本
# 对应 Linux 版的 run.sh，功能包括：
#   1. 打印启动横幅和环境信息
#   2. 导入自定义 CA 证书（Windows 证书存储）
#   3. 配置 NPM 国内镜像站
#   4. 加载自定义初始化脚本
#   5. 从模板渲染配置文件
#   6. 注册 Runner（临时模式，带超时重试）
#   7. 启动守护进程并监控空闲超时

$ErrorActionPreference = 'Stop'

function Log-Info {
    param([Parameter(ValueFromPipeline = $true)][string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "$timestamp INFO $Message"
}

function Log-Error {
    param([Parameter(ValueFromPipeline = $true)][string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "$timestamp ERROR $Message" -ForegroundColor Red
}

#################################################################
# 打印启动横幅和环境信息
#################################################################
Write-Host @'
   _____ _ _               _____
  / ____(_) |             |  __ \
 | |  __ _| |_ ___  __ _  | |__) |   _ _ __  _ __   ___ _ __
 | | |_ | | __/ _ \/ _` | |  _  / | | | '_ \| '_ \ / _ \ '__|
 | |__| | | ||  __/ (_| | | | \ \ |_| | | | | | | |  __/ |
  \_____|_|\__\___|\__,_| |_|  \_\__,_|_| |_|_| |_|\___|_|
'@

Write-Host

Log-Info "$(gitea-runner --version)"
Log-Info "Hostname: $env:COMPUTERNAME"

# 输出本机 IP 地址
try {
    $hostEntry = [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME)
    $ips = $hostEntry.AddressList | Where-Object { $_.AddressFamily -eq 'InterNetwork' -and $_.IPAddressToString -ne '127.0.0.1' }
    foreach ($ip in $ips) {
        Log-Info "IP Address: $($ip.IPAddressToString)"
    }
} catch {
    Log-Info 'IP Address: (unable to determine)'
}

Log-Info 'Config environment variables: '
# 输出 GITEA_/ACT_ 开头的环境变量，对敏感信息（TOKEN/SECRET/PASSWORD）脱敏
$envVars = Get-ChildItem env: | Where-Object { $_.Name -match '^GITEA_|^ACT_' } | Sort-Object Name
foreach ($var in $envVars) {
    $value = $var.Value
    if ($var.Name -match '(TOKEN|SECRET|PASSWORD)') {
        $value = '*' * $value.Length
    }
    Log-Info " - $($var.Name)=$value"
}


#################################################################
# 导入自定义 CA 证书（若挂载目录存在证书文件）
# 系统侧：通过 certutil 导入到 Windows 根证书存储
#################################################################
if ((Test-Path $env:CA_CERT_DIR) -and (Get-ChildItem $env:CA_CERT_DIR -File -ErrorAction SilentlyContinue)) {
    Log-Info "Importing CA certificates from $env:CA_CERT_DIR ..."
    $counter = 0
    Get-ChildItem $env:CA_CERT_DIR -File | Sort-Object Name | ForEach-Object {
        $counter++
        Log-Info "  Importing $($_.Name) ..."
        certutil -addstore -f root $_.FullName
    }
    Log-Info "Imported $counter CA certificate(s)."
} else {
    Log-Info "No CA certificates to import (directory $env:CA_CERT_DIR empty or missing)."
}


#################################################################
# 配置 NPM 默认镜像仓库
#################################################################
npm config set registry $env:NPM_REGISTRY
Log-Info "NPM registry set to $env:NPM_REGISTRY"


#################################################################
# 加载自定义初始化脚本 (如指定了 INIT_PS1_FILE)
#################################################################
if ($env:INIT_PS1_FILE -and (Test-Path $env:INIT_PS1_FILE)) {
    Log-Info "Loading [$env:INIT_PS1_FILE]..."
    . $env:INIT_PS1_FILE
}


#################################################################
# 从模板渲染配置文件 (用环境变量替换模板中的占位符)
# 支持 ${VAR:-default} 和 ${VAR//old/new} 两种 bash 风格占位符
#################################################################
function Render-ConfigTemplate {
    param(
        [string]$TemplateFile,
        [string]$OutputFile
    )

    # Windows PowerShell 5.1 的 Get-Content 默认按 ANSI(GBK) 解码，
    # 会把无 BOM 的 UTF-8 模板中的中文误读为乱码字节，再写回 yaml 后
    # 导致 Go yaml 解析器报 "control characters are not allowed"。
    # 显式指定 UTF8 让中文等非 ASCII 字符正确解码。
    $content = Get-Content $TemplateFile -Raw -Encoding UTF8

    # Step 1: 处理 ${VAR//old/new} 模式（bash 风格字符串替换）
    $transformRegex = [regex]'\$\{(\w+)//([^/]+)/([^}]*)\}'
    $transformMatches = $transformRegex.Matches($content)
    for ($i = $transformMatches.Count - 1; $i -ge 0; $i--) {
        $m = $transformMatches[$i]
        $varName = $m.Groups[1].Value
        $oldStr = $m.Groups[2].Value
        $newStr = $m.Groups[3].Value
        # 将 \" 转义为 "（兼容 bash eval 语义）
        $newStr = $newStr.Replace('\"', '"')
        $envValue = [Environment]::GetEnvironmentVariable($varName)
        $replacement = if ($envValue) { $envValue.Replace($oldStr, $newStr) } else { '' }
        $content = $content.Substring(0, $m.Index) + $replacement + $content.Substring($m.Index + $m.Length)
    }

    # Step 2: 处理 ${VAR:-default} 和 ${VAR} 模式
    $defaultRegex = [regex]'\$\{(\w+)(?::-([^}]*))?\}'
    $defaultMatches = $defaultRegex.Matches($content)
    for ($i = $defaultMatches.Count - 1; $i -ge 0; $i--) {
        $m = $defaultMatches[$i]
        $varName = $m.Groups[1].Value
        $default = $m.Groups[2].Value
        $envValue = [Environment]::GetEnvironmentVariable($varName)
        $replacement = if ($envValue) { $envValue } else { $default }
        $content = $content.Substring(0, $m.Index) + $replacement + $content.Substring($m.Index + $m.Length)
    }

    # 使用 .NET API 写入 UTF-8 无 BOM 文件。
    # Windows PowerShell 5.1 的 Set-Content -Encoding UTF8 会写入 3 字节 BOM (EF BB BF)，
    # gitea-runner 使用的 Go yaml.v3 解析器会把 BOM 当作控制字符拒绝：
    #   yaml: control characters are not allowed
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($OutputFile, $content, $utf8NoBom)
}

# 若未指定 runner 标签, 则使用默认标签
if (-not $env:GITEA_RUNNER_LABELS) {
    $env:GITEA_RUNNER_LABELS = $env:GITEA_RUNNER_LABELS_DEFAULT
}

$effectiveConfigFile = 'C:\opt\gitea_runner_config.yml'
Render-ConfigTemplate -TemplateFile $env:GITEA_RUNNER_CONFIG_TEMPLATE_FILE -OutputFile $effectiveConfigFile


#################################################################
# 注册 runner (若未注册过则向 Gitea 实例注册)
#################################################################
$dataDir = 'C:\data'
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
Set-Location $dataDir

$registrationFile = "$dataDir\.runner"
if (-not (Test-Path $registrationFile) -or (Get-Item $registrationFile).Length -eq 0) {
    # 未直接提供 token 时, 从文件读取
    if (-not $env:GITEA_RUNNER_REGISTRATION_TOKEN) {
        $env:GITEA_RUNNER_REGISTRATION_TOKEN = (Get-Content $env:GITEA_RUNNER_REGISTRATION_TOKEN_FILE -Raw).Trim()
    }

    Log-Info 'Trying to register runner with Gitea...'
    Log-Info "  GITEA_INSTANCE_URL=$env:GITEA_INSTANCE_URL"
    Log-Info "  GITEA_RUNNER_NAME=$env:GITEA_RUNNER_NAME"
    $tokenMask = '*' * $env:GITEA_RUNNER_REGISTRATION_TOKEN.Length
    Log-Info "  GITEA_RUNNER_REGISTRATION_TOKEN=$tokenMask"
    Log-Info "  GITEA_RUNNER_LABELS=$env:GITEA_RUNNER_LABELS"
    Log-Info '  Ephemeral mode enabled (runner will exit after completing one job)'

    # 使用 --flag=value 形式（而非 --flag value 两元素），避免当 env 变量为空字符串时
    # PowerShell 在 Windows 命令行拼装阶段丢弃空 token，导致 pflag 误吞后续 flag
    # 使下一个值成为 leftover 位置参数，触发 cobra MaximumNArgs(0) 校验失败。
    $registerArgs = @(
        'register',
        "--instance=$env:GITEA_INSTANCE_URL",
        "--token=$env:GITEA_RUNNER_REGISTRATION_TOKEN",
        "--name=$env:GITEA_RUNNER_NAME",
        "--labels=$env:GITEA_RUNNER_LABELS",
        "--config=$effectiveConfigFile",
        '--no-interactive',
        '--ephemeral'
    )

    $timeoutSeconds = [int]$env:GITEA_RUNNER_REGISTRATION_TIMEOUT
    $retryInterval = [int]$env:GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)

    while ($true) {
        & gitea-runner @registerArgs
        if ($LASTEXITCODE -eq 0) {
            break
        }
        if ((Get-Date) -ge $deadline) {
            Log-Error 'Runner registration failed.'
            exit 1
        }
        Start-Sleep -Seconds $retryInterval
    }
}


#################################################################
# 保存超时配置，然后清除所有 GITEA_ 环境变量
#################################################################
$runnerTimeoutMinutes = [int]$env:GITEA_RUNNER_TIMEOUT_MINUTES
Get-ChildItem env: | Where-Object { $_.Name -match '^GITEA_' } | ForEach-Object {
    Remove-Item "env:\$($_.Name)" -ErrorAction SilentlyContinue
}


#################################################################
# 启动 Gitea Actions runner 守护进程
#################################################################
$daemonLog = 'C:\opt\daemon.log'
$daemonErr = 'C:\opt\daemon.err'

$daemonProcess = Start-Process -FilePath 'gitea-runner' `
    -ArgumentList 'daemon', '--config', $effectiveConfigFile `
    -RedirectStandardOutput $daemonLog `
    -RedirectStandardError $daemonErr `
    -NoNewWindow -PassThru

# 计算超时时间戳（默认 60 分钟）
$timeoutSeconds = $runnerTimeoutMinutes * 60
$deadline = (Get-Date).AddSeconds($timeoutSeconds)
Log-Info "Container timeout: ${runnerTimeoutMinutes}m (will exit after $($deadline.ToString('HH:mm:ss')))"

# 主循环：等待 runner 完成/异常退出/超时
$taskDetected = $false
while ($true) {
    # 检查 runner 是否存活
    if ($daemonProcess.HasExited) {
        Log-Info 'Gitea runner process exited.'
        break
    }

    # 检测 daemon 日志中是否出现任务接收标记
    if (-not $taskDetected) {
        $logContent = ''
        if (Test-Path $daemonLog) {
            $logContent += Get-Content $daemonLog -Raw -ErrorAction SilentlyContinue
        }
        if (Test-Path $daemonErr) {
            $logContent += Get-Content $daemonErr -Raw -ErrorAction SilentlyContinue
        }
        if ($logContent -match 'task \d+ repo|Running job') {
            $taskDetected = $true
            $deadline = (Get-Date).AddSeconds($timeoutSeconds)
            Log-Info "Task received from server, timeout extended to ${runnerTimeoutMinutes}m (will exit after $($deadline.ToString('HH:mm:ss')))"
        }
    }

    # 检查超时
    if ((Get-Date) -ge $deadline) {
        Log-Info "Container idle timeout (${runnerTimeoutMinutes}m) reached, exiting."
        break
    }
    Start-Sleep -Seconds 60
}

Log-Info 'Container exiting.'
exit 0
