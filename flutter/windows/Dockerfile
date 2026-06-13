# escape=`

# 使用微软预构建镜像（已包含 MSBuild、.NET Framework SDK）
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG FLUTTER_VERSION=3.44.1
ARG GIT_INSTALLATION_PATH="C:\Program Files\Git"

ENV FLUTTER_ROOT="C:\flutter"
ENV FLUTTER_GIT_URL="unknown source"
ENV PUB_CACHE="C:\pub-cache"

WORKDIR "C:\app"

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

# 授予 ContainerAdministrator 创建符号链接的权限（Flutter 插件需要）
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

# 设置系统 PATH
RUN [Environment]::SetEnvironmentVariable('PATH', \"${env:PATH};${env:GIT_INSTALLATION_PATH}\cmd;${env:GIT_INSTALLATION_PATH}\usr\bin;${env:FLUTTER_ROOT}\bin;${env:FLUTTER_ROOT}\bin\cache\dart-sdk\bin\", 'Machine')

# 修复 MinGit 的循环引用问题
RUN $env:GIT_CONFIG_NOSYSTEM=1; git config --system --unset-all include.path

# 安装 VC++ 工具链（必须在 Flutter 初始化之前，否则 flutter precache 无法正确设置 Windows 支持）
# 安装组件：Desktop C++ workload + MSVC v143 + MSVC v142 + CMake + Windows 10 SDK（Flutter 必需）+ Windows 11 SDK
RUN Invoke-WebRequest -Uri https://aka.ms/vs/17/release/vs_buildtools.exe -OutFile C:\vs_buildtools.exe; `
    Start-Process C:\vs_buildtools.exe -ArgumentList \"--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.14.29.x86.x64 --add Microsoft.VisualStudio.Component.VC.14.29.16.11.x86.x64 --add Microsoft.VisualStudio.Component.VC.CMake.Project --add Microsoft.VisualStudio.Component.Windows10SDK.19041 --add Microsoft.VisualStudio.Component.Windows11SDK.22000\" -Wait; `
    Remove-Item C:\vs_buildtools.exe -Force -ErrorAction SilentlyContinue

# 禁用 MSBuild 节点复用，并初始化 VC++ 环境变量
RUN setx /M MSBUILDDISABLENODEREUSE 1; `
    $vswhere = \"${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe\"; `
    $vcvars = & $vswhere -latest -property installationPath; `
    Write-Host \"VS installation: $vcvars\"

# 克隆 Flutter SDK
RUN git clone --depth 1 --branch \"$env:FLUTTER_VERSION\" https://github.com/flutter/flutter.git \"$env:FLUTTER_ROOT\"; `
    git config --global --add safe.directory \"$env:FLUTTER_ROOT\"; `
    flutter --version; `
    dart --disable-analytics; `
    flutter config --no-cli-animations --no-analytics --no-enable-android --no-enable-web --no-enable-linux-desktop --enable-windows-desktop --no-enable-fuchsia --no-enable-custom-devices --no-enable-ios --no-enable-macos-desktop; `
    flutter doctor --verbose; `
    flutter precache --windows
