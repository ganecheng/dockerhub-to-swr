# escape=`

# 基础镜像：Windows Server Core + VS Build Tools + Git
# 不含 Flutter SDK，供 Flutter Windows 构建镜像继承
FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG GIT_INSTALLATION_PATH="C:\Program Files\Git"

# 启用 TLS 1.2（防止 Schannel 协商失败）—— Client 和 Server 端都需要
RUN $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2'; `
    foreach ($side in @('Client', 'Server')) { `
      New-Item -Path \"$path\$side\" -Force | Out-Null; `
      Set-ItemProperty -Path \"$path\$side\" -Name 'DisabledByDefault' -Value 0 -Type DWord; `
      Set-ItemProperty -Path \"$path\$side\" -Name 'Enabled' -Value 1 -Type DWord `
    }

# 更新根证书，否则中国镜像站点（pub.flutter-io.cn 等）TLS 握手会失败
RUN certutil -generateSSTFromWU C:\roots.sst; `
    certutil -addstore -f root C:\roots.sst; `
    Remove-Item C:\roots.sst -Force

# 安装 PowerShell 7 并切换为后续构建步骤的默认 shell
# PS 5.1 在 $ErrorActionPreference='Stop' 下会把原生命令 stderr 升级为终止性错误，
# 使得诸如"git config --unset-all 在键不存在时以非零码退出"这类正常幂等场景
# 直接中止 RUN。PS 7 修正了该缺陷，原生命令 stderr 不再触发终止性错误。
# 后续如需调用 .sh 脚本，仍使用 Git Bash（C:\Program Files\Git\bin\bash.exe，
# 由后一步加入系统 PATH）。
RUN $installer = \"PowerShell-7.4.7-win-x64.msi\"; `
    $url = \"https://github.com/PowerShell/PowerShell/releases/download/v7.4.7/${installer}\"; `
    Invoke-WebRequest -Uri $url -OutFile $installer; `
    $installArgs = @( '/i', $installer, '/quiet', '/norestart' ); `
    $proc = Start-Process msiexec -ArgumentList $installArgs -Wait -PassThru -NoNewWindow; `
    if ($proc.ExitCode -ne 0) { `
      Get-ChildItem $env:TEMP -Filter 'MSI*.LOG' -ErrorAction SilentlyContinue | ForEach-Object { `
        Write-Host \"========== $($_.FullName) ==========\"; Get-Content $_.FullName -ErrorAction SilentlyContinue `
      }; `
      throw \"PowerShell 7 安装失败，退出码: $($proc.ExitCode)\" `
    }; `
    Remove-Item $installer -Force

# 切换 SHELL 到 PowerShell 7，后续 RUN 全局改由 pwsh 执行
SHELL [\"pwsh\", \"-NoLogo\", \"-NoProfile\", \"-Command\", \"$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';\"]

# 授予 ContainerAdministrator 创建符号链接的权限
RUN $tempCfg = \"$env:TEMP\secpol.cfg\"; `
    $tempDb = \"$env:TEMP\secpol.sdb\"; `
    secedit /export /cfg $tempCfg /areas USER_RIGHTS /quiet; `
    $content = Get-Content $tempCfg -Encoding Unicode; `
    $sid = (New-Object System.Security.Principal.NTAccount('ContainerAdministrator')).Translate([System.Security.Principal.SecurityIdentifier]).Value; `
    $found = $false; `
    $newContent = @(); `
    foreach ($line in $content) { `
      if ($line -match '^SeCreateSymbolicLinkPrivilege\s*=') { `
        $found = $true; `
        if ($line -notmatch [regex]::Escape($sid)) { `
          $line = $line.TrimEnd() + ',*' + $sid `
        } `
      }; `
      $newContent += $line `
    }; `
    if (-not $found) { `
      $newContent += ('SeCreateSymbolicLinkPrivilege = *' + $sid) `
    }; `
    $newContent | Set-Content $tempCfg -Encoding Unicode; `
    secedit /configure /db $tempDb /cfg $tempCfg /areas USER_RIGHTS /quiet; `
    Remove-Item $tempCfg, $tempDb -Force -ErrorAction SilentlyContinue

# 安装完整版 Git for Windows（含 Git Bash / MSYS2 运行时与常用 Unix 工具）
# 完整版相比 MinGit 多出 bash.exe 与 awk/sed/grep/curl 等 Unix 工具，
# 也提供 Git Bash 终端，使后续安装/启动脚本可改用 Git Bash 执行。
# 使用 Inno Setup 静默安装参数：/VERYSILENT 不显示 UI，/NORESTART 不重启，
# /SP- 抑制"将安装该程序"提示，/DIR=... 指定安装目录（与 GIT_INSTALLATION_PATH 对齐）。
RUN $installer = \"Git-2.54.0-64-bit.exe\"; `
    $url = \"https://github.com/git-for-windows/git/releases/download/v2.54.0.windows.1/${installer}\"; `
    Invoke-WebRequest -Uri \"$url\" -OutFile \"$installer\"; `
    $installArgs = @( `
      '/VERYSILENT', '/NORESTART', '/NOCANCEL', '/SP-', `
      '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS', `
      \"/DIR=${env:GIT_INSTALLATION_PATH}\" `
    ); `
    $proc = Start-Process -FilePath \"$installer\" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow; `
    if ($proc.ExitCode -ne 0) { `
      Get-ChildItem $env:TEMP -Filter 'Install*.log' -ErrorAction SilentlyContinue | ForEach-Object { `
        Write-Host \"========== $($_.FullName) ==========\"; Get-Content $_.FullName -ErrorAction SilentlyContinue `
      }; `
      throw \"Git for Windows 安装失败，退出码: $($proc.ExitCode)\" `
    }; `
    Remove-Item -Path \"$installer\" -Force

# 设置系统 PATH（仅 Git 路径，不含 Flutter）
# 完整版 Git for Windows 的 bin\bash.exe 与 usr\bin 下的 MSYS2 工具均通过此 PATH 暴露
RUN [Environment]::SetEnvironmentVariable('PATH', \"${env:PATH};${env:GIT_INSTALLATION_PATH}\cmd;${env:GIT_INSTALLATION_PATH}\usr\bin\", 'Machine')

# 修复 Git for Windows 的循环引用问题（MinGit 与完整版均可能触发）
# 全新安装的 system config 通常不含 include.path，git config --unset-all 会写
# "No such section!" 到 stderr 并以非零码退出。PS 7 不会将原生命令 stderr 升级为
# 终止性错误，但 pwsh -Command 退出码会取自 $LASTEXITCODE，故显式重置为 0
# 以确保 RUN 不被非零退出码终结（include.path 不存在视为已达成"无 include.path"）。
RUN $env:GIT_CONFIG_NOSYSTEM=1; git config --system --unset-all include.path; $LASTEXITCODE = 0

# 下载并安装 VS Build Tools 组件（合并为单层，避免分层后体积膨胀）
# 包含：VCTools 工作负载、MSVC v143、Windows 10 SDK 19041、CMake 工具
# --nocache 已禁用本地缓存，安装完成后清理所有临时文件
# 退出码 0 = 成功；3010 = 成功但需重启（容器内视为成功）；其他 = 失败
RUN Invoke-WebRequest -Uri https://aka.ms/vs/17/release/vs_buildtools.exe -OutFile C:\vs_buildtools.exe; `
    $components = @( `
      'Microsoft.VisualStudio.Workload.VCTools', `
      'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', `
      'Microsoft.VisualStudio.Component.Windows10SDK.19041', `
      'Microsoft.VisualStudio.Component.VC.CMake.Project' `
    ); `
    $vsArgs = @( '--quiet', '--wait', '--norestart', '--nocache', '--installPath', 'C:\BuildTools' ); `
    foreach ($comp in $components) { `
      $vsArgs += '--add'; $vsArgs += $comp `
    }; `
    $proc = Start-Process C:\vs_buildtools.exe -ArgumentList $vsArgs -Wait -PassThru -NoNewWindow; `
    $code = $proc.ExitCode; `
    if ($code -ne 0 -and $code -ne 3010) { `
      Get-ChildItem $env:TEMP -Filter 'dd_*.log' -ErrorAction SilentlyContinue | ForEach-Object { `
        Write-Host \"========== $($_.FullName) ==========\"; Get-Content $_.FullName -ErrorAction SilentlyContinue `
      }; `
      throw \"VS Build Tools 安装失败，退出码: $code\" `
    }; `
    Remove-Item C:\vs_buildtools.exe -Force -ErrorAction SilentlyContinue; `
    Remove-Item 'C:\ProgramData\Package Cache' -Recurse -Force -ErrorAction SilentlyContinue; `
    Write-Host \"VS Build Tools 全部组件安装完成（退出码: $code）\"

# 安装 NuGet（Flutter Windows 构建依赖）
# 放到 C:\nuget 而非 System32，避免 WOW64 文件系统重定向问题；
# 同时将路径加入系统 PATH，32/64 位进程均可正常找到
RUN $nugetDir = 'C:\nuget'; `
    New-Item -ItemType Directory -Path $nugetDir -Force | Out-Null; `
    $nugetPath = Join-Path $nugetDir 'nuget.exe'; `
    Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nugetPath; `
    [Environment]::SetEnvironmentVariable('PATH', \"${env:PATH};${nugetDir}\", 'Machine')

# 禁用 MSBuild 节点复用，初始化 VC++ 环境变量并写入系统 PATH
# 直接使用已知安装路径 C:\BuildTools（vswhere 默认不会扫描非标准路径）
RUN setx /M MSBUILDDISABLENODEREUSE 1; `
    $vsPath = 'C:\BuildTools'; `
    Write-Host \"VS installation: $vsPath\"; `
    $msvcPath = Join-Path $vsPath 'VC\Tools\MSVC'; `
    if (-not (Test-Path $msvcPath)) { throw \"MSVC 目录不存在: $msvcPath（VS Build Tools 安装可能失败）\" }; `
    $msvcVer = (Get-ChildItem $msvcPath -Directory | Sort-Object Name -Descending | Select-Object -First 1).Name; `
    $hostArch = if ([Environment]::Is64BitOperatingSystem) { 'Hostx64' } else { 'Hostx86' }; `
    $targetArch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }; `
    $binPath = Join-Path $msvcPath \"$msvcVer\bin\$hostArch\$targetArch\"; `
    Write-Host \"MSVC tools: $binPath\"; `
    if (-not (Test-Path $binPath)) { throw \"MSVC 工具路径不存在: $binPath\" }; `
    [Environment]::SetEnvironmentVariable('PATH', \"${env:PATH};${binPath}\", 'Machine')