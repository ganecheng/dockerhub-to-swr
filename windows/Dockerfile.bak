# escape=`

# Windows Server Core + Git + VS Build Tools，不含 Flutter SDK
# 供 Flutter Windows 构建镜像继承
FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG GIT_INSTALLATION_PATH="C:\Program Files\Git"

# 启用 TLS 1.2，避免 Schannel 协商失败
RUN $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2'; `
    foreach ($side in @('Client', 'Server')) { `
      New-Item -Path \"$path\$side\" -Force | Out-Null; `
      Set-ItemProperty -Path \"$path\$side\" -Name 'DisabledByDefault' -Value 0 -Type DWord; `
      Set-ItemProperty -Path \"$path\$side\" -Name 'Enabled' -Value 1 -Type DWord `
    }

# 更新根证书，否则中国镜像站点 TLS 握手会失败
RUN certutil -generateSSTFromWU C:\roots.sst; `
    certutil -addstore -f root C:\roots.sst; `
    Remove-Item C:\roots.sst -Force

# 安装 PowerShell 7：PS 5.1 在 $ErrorActionPreference='Stop' 下会将原生命令 stderr 升级为终止性错误，
# 导致 git config --unset-all 等幂等场景异常退出。PS 7 修正了该缺陷。
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

# 切换 SHELL 到 PowerShell 7
SHELL ["pwsh", "-NoLogo", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

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

# 安装完整版 Git for Windows（含 Git Bash / MSYS2 Unix 工具）
# Inno Setup 静默参数：/VERYSILENT 无 UI，/SP- 抑制安装提示
# 注意：-ArgumentList 必须用单字符串传入。若用数组形式，PowerShell 会对含空格的 /DIR=... 整体
# 加引号生成 "/DIR=C:\Program Files\Git"，Inno Setup 不识别此格式（要求 /DIR="..."），
# 在空格处截断导致安装到 C:\Program 而非 C:\Program Files\Git
# 用 [char]34 产生双引号字符，避免 Dockerfile 转义层级混乱
RUN $installer = \"Git-2.54.0-64-bit.exe\"; `
    $url = \"https://github.com/git-for-windows/git/releases/download/v2.54.0.windows.1/${installer}\"; `
    Invoke-WebRequest -Uri \"$url\" -OutFile \"$installer\"; `
    $q = [char]34; `
    $installArgs = '/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /DIR=' + $q + $env:GIT_INSTALLATION_PATH + $q; `
    $proc = Start-Process -FilePath \"$installer\" -ArgumentList $installArgs -Wait -PassThru -NoNewWindow; `
    if ($proc.ExitCode -ne 0) { `
      Get-ChildItem $env:TEMP -Filter 'Install*.log' -ErrorAction SilentlyContinue | ForEach-Object { `
        Write-Host \"========== $($_.FullName) ==========\"; Get-Content $_.FullName -ErrorAction SilentlyContinue `
      }; `
      throw \"Git for Windows 安装失败，退出码: $($proc.ExitCode)\" `
    }; `
    Remove-Item -Path \"$installer\" -Force; `
    if (-not (Test-Path \"${env:GIT_INSTALLATION_PATH}\bin\bash.exe\")) { `
      throw \"Git Bash 未安装在预期路径: ${env:GIT_INSTALLATION_PATH}\bin\bash.exe\" `
    }

# 将 Git cmd 与 MSYS2 工具目录加入系统 PATH
RUN [Environment]::SetEnvironmentVariable('PATH', \"${env:PATH};${env:GIT_INSTALLATION_PATH}\cmd;${env:GIT_INSTALLATION_PATH}\usr\bin\", 'Machine')

# 移除 system config 中可能导致循环引用的 include.path
# 全新安装时该键不存在，git config --unset-all 以非零码退出；显式重置 $LASTEXITCODE=0 使 RUN 不被终结
RUN $env:GIT_CONFIG_NOSYSTEM=1; git config --system --unset-all include.path; $LASTEXITCODE = 0

# 安装 VS Build Tools：VCTools、MSVC v143、Windows 10 SDK 19041、CMake
# --nocache 禁用本地缓存；退出码 3010 = 需重启，容器内视为成功
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

# 安装 NuGet（Flutter Windows 构建依赖），放入独立目录避免 WOW64 重定向
RUN $nugetDir = 'C:\nuget'; `
    New-Item -ItemType Directory -Path $nugetDir -Force | Out-Null; `
    $nugetPath = Join-Path $nugetDir 'nuget.exe'; `
    Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nugetPath; `
    [Environment]::SetEnvironmentVariable('PATH', \"${env:PATH};${nugetDir}\", 'Machine')

# 禁用 MSBuild 节点复用，将 MSVC 工具路径加入系统 PATH
# 直接使用已知路径 C:\BuildTools，因 vswhere 不扫描非标准安装路径
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