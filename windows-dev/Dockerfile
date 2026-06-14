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

# 安装 MinGit（直接下载）
RUN $installer = \"MinGit-2.54.0-busybox-64-bit.zip\"; `
    $url = \"https://github.com/git-for-windows/git/releases/download/v2.54.0.windows.1/${installer}\"; `
    Invoke-WebRequest -Uri \"$url\" -OutFile \"$installer\"; `
    Expand-Archive -Path \"$installer\" -DestinationPath \"$env:GIT_INSTALLATION_PATH\"; `
    Remove-Item -Path \"$installer\"

# 设置系统 PATH（仅 Git 路径，不含 Flutter）
RUN [Environment]::SetEnvironmentVariable('PATH', \"${env:PATH};${env:GIT_INSTALLATION_PATH}\cmd;${env:GIT_INSTALLATION_PATH}\usr\bin\", 'Machine')

# 修复 MinGit 的循环引用问题
RUN $env:GIT_CONFIG_NOSYSTEM=1; git config --system --unset-all include.path

# 下载 VS Build Tools 安装器
# 退出码 0 = 成功；3010 = 成功但需重启（容器内视为成功）；其他 = 失败
RUN Invoke-WebRequest -Uri https://aka.ms/vs/17/release/vs_buildtools.exe -OutFile C:\vs_buildtools.exe

# 一次性安装全部 VS Build Tools 组件（合并为一个 RUN 层，避免分层后体积膨胀）
# 包含：VCTools 工作负载、MSVC v143、Windows 10 SDK 19041、CMake 工具
# --nocache 已禁用本地缓存，安装完成后清理所有临时文件
RUN $components = @( `
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
RUN Invoke-WebRequest -Uri https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile C:\Windows\System32\nuget.exe

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