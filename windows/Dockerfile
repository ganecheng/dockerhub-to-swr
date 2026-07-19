# escape=`

# Windows Server Core + Git + VS Build Tools，不含 Flutter SDK
# 供 Flutter Windows 构建镜像继承
FROM amitie10g/visualstudio2022-workload-vctools:ltsc2025

# 以 ContainerAdministrator 构建和运行
USER ContainerAdministrator

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# 将 ContainerAdministrator 加入 Administrators 组
RUN Add-LocalGroupMember -Group "Administrators" -Member "ContainerAdministrator" 2>$null; $LASTEXITCODE = 0

# 启用 TLS 1.2
RUN $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2'; `
    foreach ($side in @('Client', 'Server')) { `
      New-Item -Path \"$path\$side\" -Force | Out-Null; `
      Set-ItemProperty -Path \"$path\$side\" -Name 'DisabledByDefault' -Value 0 -Type DWord; `
      Set-ItemProperty -Path \"$path\$side\" -Name 'Enabled' -Value 1 -Type DWord `
    }

# 更新根证书
RUN certutil -generateSSTFromWU C:\roots.sst | Out-Null; `
    certutil -addstore -f root C:\roots.sst | Out-Null; `
    Remove-Item C:\roots.sst -Force

# PS 5.1 在 $ErrorActionPreference='Stop' 下会将原生命令 stderr 升级为终止性错误
RUN choco install powershell-core -y --no-progress; `
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine'); `
    pwsh --version

SHELL ["pwsh", "-NoLogo", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# 启用开发者模式以允许创建符号链接
RUN New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Force | Out-Null; `
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" `
      -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord; `
    $testDir = "$env:TEMP\symlink_test_target"; `
    $testLink = "$env:TEMP\symlink_test_link"; `
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null; `
    if (Test-Path $testLink) { Remove-Item $testLink -Force }; `
    New-Item -ItemType SymbolicLink -Path $testLink -Target $testDir | Out-Null; `
    if (Test-Path $testLink) { Write-Host "Symlink creation: OK" } else { throw "Symlink creation failed" }; `
    Remove-Item $testLink, $testDir -Force -ErrorAction SilentlyContinue

# 安装 Git for Windows（含 Git Bash / MSYS2）
RUN choco install git -y --no-progress; `
    $p = [Environment]::GetEnvironmentVariable('PATH', 'Machine'); `
    [Environment]::SetEnvironmentVariable('PATH', \"$p;C:\Program Files\Git\bin\", 'Machine'); `
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine'); `
    git --version; `
    bash -c 'echo Git Bash OK'

# 移除可能导致循环引用的 system include.path；键不存在时 --unset-all 非零退出，需重置 $LASTEXITCODE
RUN $env:GIT_CONFIG_NOSYSTEM=1; git config --system --unset-all include.path; $LASTEXITCODE = 0

# 安装 NuGet
RUN choco install nuget.commandline -y --no-progress; `
    nuget help | Select-Object -First 1

# 打印 VS Build Tools 相关组件版本，确认安装成功
RUN $vswhere = \"${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe\"; `
    $installs = & $vswhere -products * -all -format json | ConvertFrom-Json; `
    $installs | ForEach-Object { \"VS: $($_.displayName) $($_.installationVersion)\" }; `
    $cl = Get-ChildItem 'C:\Program Files (x86)\Microsoft Visual Studio\2022\*\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe' -ErrorAction SilentlyContinue; `
    if ($cl) { $cl | ForEach-Object { \"VC.Tools: $($_.Directory.Parent.Parent.Parent.Name)\" } } else { \"VC.Tools: 未找到\" }; `
    $sdk = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\Include' -Directory -ErrorAction SilentlyContinue; `
    if ($sdk) { $sdk | ForEach-Object { \"Windows SDK: $($_.Name)\" } } else { \"Windows SDK: 未找到\" }; `
    $cmake = Test-Path 'C:\Program Files (x86)\Microsoft Visual Studio\2022\*\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'; `
    \"CMake: $(if ($cmake) { '已安装' } else { '未找到' })\"

ENTRYPOINT []
CMD ["pwsh", "-NoLogo", "-NoProfile"]
