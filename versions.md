# 依赖的开源组件版本号

> 本文件统计本仓库中所有 Dockerfile、GitHub Actions workflow 和 shell 脚本引用的开源组件版本号。
>
> 最后更新：2026-07-22

---

## 1. 基础镜像

| 组件 | 版本 | MAJOR 最新版本 | MINOR 最新版本 | 引用文件 | 说明 |
|------|------|----------------|----------------|----------|------|
| Ubuntu (resolute) | `resolute-20260707` | `resolute-20260707` (已是最新) | `resolute-20260707` (已是最新) | `ubuntu/Dockerfile` | Ubuntu 26.04 基础镜像 |
| NVIDIA CUDA | `13.2.1-cudnn-runtime-ubuntu24.04` | `13.3.1` | `13.3.1` | `pytorch/Dockerfile` | PyTorch GPU 运行时基础镜像 |
| Windows Server Core (ltsc2025) | `ltsc2025` | `ltsc2025` (已是最新) | `ltsc2025` (已是最新) | `windows/Dockerfile` (via `amitie10g/visualstudio2022-workload-vctools`) | Windows 构建基础镜像 |
| Windows Server Core (ltsc2022) | `ltsc2022` | `ltsc2025` | `ltsc2022` (已是最新) | `windows/Dockerfile.bak` (via `mcr.microsoft.com/windows/servercore`) | 旧版 Windows 构建基础镜像（备份） |
| 自建 Ubuntu 镜像 | `20260722_201300` | - | - | `k3s/Dockerfile`, `dumbproxy/Dockerfile`, `download_file/Dockerfile`, `gitea-runner-ubuntu/Dockerfile`, `ace-step/Dockerfile`, `indextts/Dockerfile`, `sensevoice/Dockerfile` | 基于 `ubuntu/Dockerfile` 构建的内部镜像 |
| 自建 Windows 镜像 | `20260720_235850` | - | - | `gitea-runner-windows/Dockerfile`, `gitea-runner-windows/Dockerfile.flutter` | 基于 `windows/Dockerfile` 构建的内部镜像 |
| 自建 PyTorch 镜像 | `20260402_002531` | - | - | `comfyui/Dockerfile` | 基于 `pytorch/Dockerfile` 构建的内部镜像 |

---

## 2. 容器运行时 & 基础设施

| 组件 | 版本 | MAJOR 最新版本 | MINOR 最新版本 | 引用文件 | 说明 |
|------|------|----------------|----------------|----------|------|
| Docker CE | `28.5.2` | `29.6.2` | `28.5.2` (已是最新) | `gitea-runner-ubuntu/Dockerfile` (静态二进制), 各 workflow (`docker/setup-docker-action@v5` with `version: 'v28.5.2'`) | 容器引擎 |
| Docker CE (apt) | apt 默认最新 | - | - | `k3s/Dockerfile` | 通过 Docker 官方 APT 源安装 |
| containerd.io | apt 默认最新 | - | - | `k3s/Dockerfile` | Docker CE 运行依赖 |
| k3s | `v1.34.9+k3s1` | `v1.36.2+k3s1` | `v1.34.9+k3s1` (已是最新) | `k3s/Dockerfile` | 轻量级 Kubernetes 发行版 |
| tini | apt 默认最新 | - | - | `ubuntu/Dockerfile` | PID 1 进程管理 |
| skopeo | apt 默认最新 | - | - | `ubuntu/Dockerfile` | 镜像同步工具 |
| yq | apt 默认最新 | - | - | `ubuntu/Dockerfile` | YAML 处理工具 |
| dumbproxy | `1.51.1` | `1.51.1` (已是最新) | `1.51.1` (已是最新) | `dumbproxy/Dockerfile` | 轻量 HTTP 代理 |

---

## 3. Gitea Runner & CI/CD 工具

| 组件 | 版本 | MAJOR 最新版本 | MINOR 最新版本 | 引用文件 | 说明 |
|------|------|----------------|----------------|----------|------|
| Gitea Runner | `1.0.8` | `2.1.0` | `1.0.8` (已是最新) | `gitea-runner-ubuntu/Dockerfile`, `gitea-runner-windows/Dockerfile` | CI/CD Runner |
| Node.js | `24.18.0` | `26.5.0` | `24.18.0` (已是最新) | `gitea-runner-ubuntu/Dockerfile`, `gitea-runner-windows/Dockerfile` | JavaScript 运行时 |
| kubectl | `1.36.2` | `1.36.2` (已是最新) | `1.36.2` (已是最新) | `gitea-runner-ubuntu/Dockerfile` | Kubernetes 命令行工具 |
| Helm | `4.2.3` | `4.2.3` (已是最新) | `4.2.3` (已是最新) | `gitea-runner-ubuntu/Dockerfile` | Kubernetes 包管理器 |

---

## 4. Java 开发环境

| 组件 | 版本 | MAJOR 最新版本 | MINOR 最新版本 | 引用文件 | 说明 |
|------|------|----------------|----------------|----------|------|
| OpenJDK 21 (Temurin) | latest GA | - | - | `gitea-runner-ubuntu/modules/jdk21.sh` | Eclipse Temurin JDK 21 |
| OpenJDK 25 (Temurin) | latest GA | - | - | `gitea-runner-ubuntu/modules/jdk25.sh`, `gitea-runner-ubuntu/modules/jmeter.sh` | Eclipse Temurin JDK 25 |
| OpenJDK 21 (apt) | apt 默认最新 | - | - | `gitea-runner-ubuntu/Dockerfile.flutter` | Android 构建用 JDK |
| GraalVM JDK 21 | latest | - | - | `gitea-runner-ubuntu/modules/graalvm-jdk21.sh` | Oracle GraalVM JDK 21 |
| GraalVM JDK 25 | latest | - | - | `gitea-runner-ubuntu/modules/graalvm-jdk25.sh` | Oracle GraalVM JDK 25 |
| Apache Maven | `3.9.16` | `4.0.0-rc-5` (非 GA) | `3.9.16` (已是最新) | `gitea-runner-ubuntu/modules/common.sh` (默认值), `graalvm-jdk21.sh`, `graalvm-jdk25.sh`, `jdk21.sh`, `jdk25.sh` | 项目构建工具 |
| Apache JMeter | `5.6.3` | `5.6.3` (已是最新) | `5.6.3` (已是最新) | `gitea-runner-ubuntu/modules/jmeter.sh`, `gitea-runner-ubuntu/modules/common.sh` (默认值) | 性能测试工具 |

---

## 5. Flutter & Android SDK

| 组件 | 版本 | MAJOR 最新版本 | MINOR 最新版本 | 引用文件 | 说明 |
|------|------|----------------|----------------|----------|------|
| Flutter SDK | `3.44.2` | `3.44.7` | `3.44.7` | `gitea-runner-ubuntu/Dockerfile.flutter`, `gitea-runner-windows/Dockerfile.flutter` | Flutter 跨平台框架 |
| Android Command-line Tools | `14742923` | `15859902` (v22.0) | `14742923` (已是最新) | `gitea-runner-ubuntu/Dockerfile.flutter` | Android SDK 命令行工具 |
| Android Platform Tools | latest | - | - | `gitea-runner-ubuntu/Dockerfile.flutter` | ADB 等平台工具 |
| Android SDK Platform 36 | API 36 | API 36 (已是最新) | API 36 (已是最新) | `gitea-runner-ubuntu/Dockerfile.flutter` | Android 36 编译平台 |
| Android SDK Platform 35 | API 35 | API 36 | API 35 (已是最新) | `gitea-runner-ubuntu/Dockerfile.flutter` | Android 35 编译平台 |
| Android Build Tools | `36.0.0` | `37.0.0` | `36.1.0` | `gitea-runner-ubuntu/Dockerfile.flutter` | Android 构建工具 |
| Android NDK 29 | `29.0.14206865` | `30.0.15729638` (r30-beta2, 非 GA) | `29.0.14206865` (已是最新) | `gitea-runner-ubuntu/Dockerfile.flutter` | Android NDK r29 |
| Android NDK 28 | `28.2.13676358` | `29.0.14206865` (r29) | `28.2.13676358` (已是最新) | `gitea-runner-ubuntu/Dockerfile.flutter` | Android NDK r28 |
| Android CMake | `3.22.1` | `4.1.2` | `3.31.6` | `gitea-runner-ubuntu/Dockerfile.flutter` | Android NDK 内置 CMake |

---

## 6. Windows 构建工具

| 组件 | 版本 | MAJOR 最新版本 | MINOR 最新版本 | 引用文件 | 说明 |
|------|------|----------------|----------------|----------|------|
| Git for Windows | `2.54.0` (v2.54.0.windows.1) | `2.55.0` | `2.55.0` | `windows/Dockerfile.bak` | Git + Git Bash / MSYS2 |
| Git (Chocolatey) | latest | - | - | `windows/Dockerfile` | 通过 Chocolatey 安装 |
| PowerShell 7 | `7.4.7` | `7.6.4` | `7.6.4` | `windows/Dockerfile.bak` | PowerShell Core |
| PowerShell (Chocolatey) | latest | - | - | `windows/Dockerfile` | 通过 Chocolatey 安装 `powershell-core` |
| NuGet | latest | - | - | `windows/Dockerfile`, `windows/Dockerfile.bak` | .NET 包管理器 |
| Chocolatey | latest | - | - | `windows/Dockerfile` | Windows 包管理器 |
| VS Build Tools 2022 | 17 release | 17 release (已是最新) | 17 release (已是最新) | `windows/Dockerfile`, `windows/Dockerfile.bak` | Visual Studio Build Tools |
| MSVC v143 | latest (VS 2022) | - | - | `windows/Dockerfile`, `windows/Dockerfile.bak` | C/C++ 编译器工具链 |
| Windows 10 SDK | `10.0.19041` | `10.0.26100` | `10.0.19041` (已是最新) | `windows/Dockerfile.bak` | Windows SDK (19041) |
| Windows SDK | latest (VS 2022 安装) | - | - | `windows/Dockerfile` | 通过 VS Build Tools 安装 |
| CMake | latest (VS 内置) | - | - | `windows/Dockerfile`, `windows/Dockerfile.bak` | C/C++ 构建系统 |

---

## 7. Python & AI 框架

| 组件 | 版本 | MAJOR 最新版本 | MINOR 最新版本 | 引用文件 | 说明 |
|------|------|----------------|----------------|----------|------|
| Python 3 | apt 默认最新 | - | - | `ubuntu/Dockerfile`, `pytorch/os_init.sh`, `ace-step/os_init.sh`, `indextts/os_init.sh` | Python 运行时 |
| PyTorch | `2.12.*` | `2.13.0` | `2.12.1` | `pytorch/install_pytorch.sh` | 深度学习框架 (CUDA 13.2) |
| torchvision | `0.27.*` | `0.28.0` | `0.27.1` | `pytorch/install_pytorch.sh` | 计算机视觉库 |
| torchcodec | `0.12.*` | `0.15.0` | `0.12.0` (已是最新) | `pytorch/install_pytorch.sh` | 视频编解码库 |
| PyTorch (CPU) | latest | - | - | `sensevoice/code.sh` | SenseVoice 使用 CPU 版 torch |
| torchaudio (CPU) | latest | - | - | `sensevoice/code.sh` | SenseVoice 使用 CPU 版 torchaudio |
| uv | latest (`-U`) | - | - | `pytorch/os_init.sh`, `ace-step/os_init.sh`, `indextts/code.sh` | Python 包管理器 |
| huggingface-hub | latest (`[cli,hf_xet]`) | - | - | `pytorch/os_init.sh`, `ace-step/os_init.sh`, `indextts/code.sh` | HuggingFace 模型下载工具 |
| modelscope | latest | - | - | `pytorch/os_init.sh`, `ace-step/os_init.sh`, `indextts/code.sh` | ModelScope 模型下载工具 |
| ffmpeg | apt 默认最新 | - | - | `pytorch/os_init.sh`, `ace-step/os_init.sh`, `sensevoice/os_init.sh`, `indextts/os_init.sh` | 音视频处理工具 |

---

## 8. AI 模型项目 (Git Commit 锁定)

| 项目 | 仓库 | Commit | 引用文件 | 说明 |
|------|------|--------|----------|------|
| ACE-Step 1.5 | `ACE-Step/ACE-Step-1.5` | `82252c2` | `ace-step/code.sh` | AI 音乐生成 |
| ComfyUI | `Comfy-Org/ComfyUI` | `700821e` | `comfyui/code.sh` | AI 图像生成工作流 |
| IndexTTS | `index-tts/index-tts` | `1698b32` | `indextts/code.sh` | AI 语音合成 (TTS) |
| SenseVoice | `FunAudioLLM/SenseVoice` | `4462e35` | `sensevoice/code.sh` | AI 语音识别 |

---

## 9. AI 模型文件

| 模型 | 来源 | 引用文件 | 说明 |
|------|------|----------|------|
| IndexTTS-2 | `IndexTeam/IndexTTS-2` (HuggingFace) | `indextts/model_indextts.sh` | IndexTTS v2 模型 |
| w2v-bert-2.0 | `facebook/w2v-bert-2.0` (HuggingFace) | `indextts/model_additional.sh` | 语音特征提取 |
| MaskGCT | `amphion/MaskGCT` (HuggingFace) | `indextts/model_additional.sh` | 语音转换模型 |
| campplus | `funasr/campplus` (HuggingFace) | `indextts/model_additional.sh` | 说话人识别 |
| bigvgan_v2 | `nvidia/bigvgan_v2_22khz_80band_256x` (HuggingFace) | `indextts/model_additional.sh` | 声码器 |
| JDCnet | `Plachta/JDCnet` (HuggingFace) | `indextts/model_additional.sh` | F0 估计 |
| SenseVoiceSmall | `iic/SenseVoiceSmall` (ModelScope) | `sensevoice/model.sh` | 语音识别模型 |
| speech_fsmn_vad | `iic/speech_fsmn_vad_zh-cn-16k-common-pytorch` (ModelScope) | `sensevoice/model.sh` | VAD 模型 |

---

## 10. GitHub Actions

| Action | 版本 | MAJOR 最新版本 | MINOR 最新版本 | 引用文件 | 说明 |
|--------|------|----------------|----------------|----------|------|
| `actions/checkout` | `v6` | `v7.0.1` | `v6.1.0` | 全部 workflow | 代码检出 |
| `docker/setup-docker-action` | `v5` | `v5.4.0` | `v5.4.0` | 全部 workflow | Docker 环境初始化 |
| `docker/login-action` | `v3` | `v4.4.0` | `v3.7.0` | 全部需登录 ghcr 的 workflow | 容器仓库登录 |
| `actions/upload-artifact` | `v7` | `v7.0.1` | `v7.0.1` | `issue-sync-image.yml` | 构建产物上传 |

---

## 11. Longhorn 存储系统镜像

以下镜像通过 `batch_sync_image/batch_sync_image_list.txt` 使用 skopeo 批量同步：

| 镜像 | 版本 | MAJOR 最新版本 | MINOR 最新版本 |
|------|------|----------------|----------------|
| `longhornio/csi-attacher` | `v4.7.0` | `v4.12.0` | `v4.7.0` (已是最新) |
| `longhornio/csi-provisioner` | `v4.0.1-20241007` | `v6.3.0` | `v4.0.1-20250204` |
| `longhornio/csi-resizer` | `v1.12.0` | `v2.2.0` | `v1.12.0` (已是最新) |
| `longhornio/csi-snapshotter` | `v7.0.2-20241007` | `v8.6.0` | `v7.0.2-20250204` |
| `longhornio/csi-node-driver-registrar` | `v2.12.0` | `v2.17.0` | `v2.12.0` (已是最新) |
| `longhornio/livenessprobe` | `v2.14.0` | `v2.19.0` | `v2.14.0` (已是最新) |
| `longhornio/backing-image-manager` | `v1.7.2` | `v1.12.0` | `v1.7.3` |
| `longhornio/longhorn-engine` | `v1.7.2` | `v1.12.0` | `v1.7.3` |
| `longhornio/longhorn-instance-manager` | `v1.7.2` | `v1.12.0` | `v1.7.3` |
| `longhornio/longhorn-manager` | `v1.7.2` | `v1.12.0` | `v1.7.3` |
| `longhornio/longhorn-share-manager` | `v1.7.2` | `v1.12.0` | `v1.7.3` |
| `longhornio/longhorn-ui` | `v1.7.2` | `v1.12.0` | `v1.7.3` |
| `longhornio/longhorn-cli` | `v1.7.2` | `v1.12.0` | `v1.7.3` |
| `longhornio/support-bundle-kit` | `v0.0.45` | `v0.0.90` | `v0.0.90` |

---

## 12. Ubuntu 系统包

以下包通过 `apt-get install` 安装在 `ubuntu/Dockerfile` 中，使用 apt 默认最新版本：

`ca-certificates` `curl` `dos2unix` `iptables` `tini` `git` `tzdata` `locales` `libfreetype6` `net-tools` `findutils` `util-linux` `zip` `unzip` `bc` `fontconfig` `sudo` `jq` `openssl` `iproute2` `iputils-ping` `telnet` `bind9-dnsutils` `wget` `zstd` `xz-utils` `bzip2` `gzip` `vim` `tree` `python3` `python3-pip` `python3-venv` `git-lfs` `skopeo` `yq`

---

## 备注

- **MAJOR 最新版本**：上游最新主版本线（可能跨大版本）的最新发布版本。
- **MINOR 最新版本**：当前使用的主版本线内的最新发布版本。
- 标注为 "-" 的组件使用 "latest" 或 "apt 默认最新" 策略，无需手动跟踪版本。
- 标注为 "已是最新" 表示当前版本即为该版本线的最新版本。
- 标注为 "apt 默认最新" 的组件未锁定具体版本号，随 Ubuntu 仓库更新而变化。
- AI 模型项目通过 git commit hash 锁定代码版本，具体依赖（如 `requirements.txt`）在构建时从上游仓库动态拉取。
- 本仓库不存在 `requirements.txt`、`package.json`、`pom.xml`、`go.mod` 等传统依赖声明文件。
- `flutter-ubuntu.yml` 和 `flutter-windows.yml` 两个 workflow 引用了已删除的 `flutter/` 目录下的 Dockerfile，运行时会失败。Flutter 构建能力现通过 `gitea-runner-ubuntu/Dockerfile.flutter` 和 `gitea-runner-windows/Dockerfile.flutter` 作为扩展镜像提供。
