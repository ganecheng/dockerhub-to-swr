# gitea-runner-windows 系列镜像

## 与 Linux 版的差异

| 维度 | Linux 版 (gitea-runner-ubuntu) | Windows 版 (gitea-runner-windows) |
|------|------------------------|----------------------------------|
| 基础镜像 | Ubuntu 26.04 | windows (Windows Server Core + VS Build Tools) |
| Shell | bash | Git Bash (随完整版 Git for Windows 提供) |
| 启动脚本 | `run.sh` | `run.sh` |
| 模块脚本 | `modules/*.sh` | `modules/*.sh` |
| CA 证书导入 | `update-ca-certificates` | `certutil -addstore` |
| 镜像站配置 | APT + PIP + NPM | 仅 NPM |
| 自定义初始化 | `INIT_SH_FILE` | `INIT_SH_FILE` |
| 配置模板渲染 | bash `eval` | bash `eval` (与 Linux 版同实现) |
| qwen 日志格式化 | `python3` + `/opt/fmt_stream.py` | `python3`/`python` + `C:\opt\bin\fmt_stream.py` |
| Runner 标签 | `ubuntu-latest,ubuntu-26.04` | `windows-latest,windows-2022` |

## 镜像结构

采用模块化设计，基础镜像（`gitea-runner-windows`）在 [windows](../windows/Dockerfile) 之上补充 Gitea Runner 运行时，各扩展镜像在此之上叠加特定场景的构建工具。

```
gitea-runner-windows/               ← 基础镜像
├── Dockerfile                      # 基础镜像 Dockerfile
├── run.sh                         # 容器入口脚本（Git Bash，Runner 注册、守护进程）
├── config.template.yaml            # Runner 配置文件模板（环境变量占位符）
├── modules/                        # 模块化安装脚本
│   ├── common.sh                   # 共享函数库 (Web 下载封装、Node.js/Qwen Code CLI/Gitea Runner/Flutter 安装)
│   ├── setup.sh                    # 基础镜像安装脚本 (Node.js + Qwen Code + Gitea Runner)
│   └── flutter.sh                  # Flutter SDK 安装模块
├── Dockerfile.flutter               # gitea-runner-windows-flutter
└── README.md
```

## 镜像列表

| 镜像名称 | Dockerfile | 包含组件 | Runner 标签 |
|---------|-----------|---------|------------|
| `gitea-runner-windows` | `Dockerfile` | windows 全部组件 + Node.js 24.21.0 + Qwen Code 0.24.5 + Python 3 (Chocolatey) + Gitea Runner 4.0.0 | `windows-latest,windows-2022` |
| `gitea-runner-windows-flutter` | `Dockerfile.flutter` | + Flutter 3.44.9 (仅 Windows 桌面) | `windows-latest,windows-2022,windows-flutter` |

> windows 已包含：Windows Server Core ltsc2025 + VS Build Tools 2022 (MSVC v143, Windows SDK, CMake) + Git for Windows（Chocolatey 最新版，含 Git Bash）+ NuGet + PowerShell 7

> 扩展镜像在基础标签之上追加各自的功能标签，无需重复声明基础标签。

## 本地构建

```powershell
# 1. 先构建基础镜像
docker build -f gitea-runner-windows/Dockerfile -t gitea-runner-windows:base .

# 2. 构建扩展镜像
docker build -f gitea-runner-windows/Dockerfile.flutter --build-arg BASE_IMAGE=gitea-runner-windows:base -t gitea-runner-windows-flutter:local .
```

## 工作原理

基础镜像在 windows 之上补充 Node.js、Qwen Code CLI 和 Gitea Runner 二进制，扩展镜像在此基础上安装特定工具（Flutter SDK 等）。构建时通过 `ARG BASE_IMAGE` 引用基础镜像，无需手动处理任何依赖关系。

### 启动流程（`run.sh`）

容器通过 Git Bash 启动 `run.sh`，按顺序执行：

1. **打印启动横幅** - 显示 Runner 版本、主机名、IP 及环境变量（敏感信息脱敏）
2. **导入自定义 CA 证书** - 通过 `certutil -addstore` 导入到 Windows 根证书存储
3. **配置 NPM 镜像站** - `npm config set registry`
4. **加载自定义初始化脚本** - 若设置了 `INIT_SH_FILE` 则 `source` 执行该脚本
5. **渲染配置文件** - 从 `config.template.yaml` 模板用环境变量替换占位符（与 Linux 版一致的 bash `eval` 方案）
6. **注册 Runner** - 临时模式（`--ephemeral`），带超时重试（默认 30s 超时、3s 重试间隔）
7. **启动守护进程并监控** - 后台运行 `gitea-runner daemon`，主循环检测空闲超时

### 临时模式与空闲超时

Runner 以 **ephemeral 模式**运行：完成一个任务后自动退出，容器随之销毁。

容器空闲超时由 `GITEA_RUNNER_TIMEOUT_MINUTES`（默认 `60`）控制。启动时计算 deadline，任务被接收后 deadline 刷新，确保任务有充足执行时间。超时后容器自动退出。

### 配置模板（`config.template.yaml`）

基于 Gitea Runner 官方示例配置，所有可配置项通过环境变量占位符替换，支持：

- Runner 并发数、任务超时、关闭超时
- 任务容器网络/特权模式/工作目录/有效卷
- 缓存服务器（actions/cache）
- Prometheus 指标端点
- 自定义环境变量注入（支持 9 组键值对）
- Job 容器 Docker 主机地址覆盖
- GitHub Action 镜像地址替换

### 自定义初始化脚本

设置 `INIT_SH_FILE` 环境变量指向容器内的 .sh 脚本路径，启动时会通过 `source` 方式执行该脚本，与 Linux 版的 `INIT_SH_FILE` 行为一致。

## 内置 Qwen Code CLI

基础镜像通过 npm 全局安装 Qwen Code CLI（当前 `0.24.5`，可用 `QWEN_CODE_VERSION` 覆盖版本），
并内置流式输出格式化脚本：仓库内 `common/fmt_stream.py`（与 Ubuntu 版共用同一份），
镜像内为 `C:\opt\bin\fmt_stream.py`。
Python 3 通过 Chocolatey 安装，且把 `python.exe` 复制为 `python3.exe`，
因此 Linux 侧的 `python3 -u .../fmt_stream.py` 调用方式可直接复用。

qwen 以 `--output-format stream-json` 运行时，每行输出一个 JSON 事件，直接查看可读性差。
`fmt_stream.py` 会将其渲染为带颜色的日志（思考、回复、工具调用、执行结果）：
思考与回复正文按终端宽度折行（续行额外缩进两列，与原文换行区分；Markdown 表格行不折行，以免
复制出去不再是合法表格），工具结果按终端宽度截断。子智能体（agent/Task）的消息整体缩进一层
并带 `↳` 标记，与主智能体的输出区分；初始化行附会话号（对应 `--debug` 日志文件名）、MCP
服务器清单与目标状态变化各占一行。最终结果整篇只打印一次——与最后一条回复重复时折叠为一行
提示，回复曾被截断时只补打剩余部分。

```bash
# 在 Git Bash 步骤中执行（workflow 里 shell: bash）
timeout 3600 \
  qwen --debug --output-format stream-json --yolo -p "任务描述" \
  2>&1 | tee result.txt | python3 -u "C:/opt/bin/fmt_stream.py" | tee pretty.txt
```

> 脚本仅依赖 Python 3 标准库；需通过 `python3 -u`（或 `python -u`）调用
> 以关闭输出缓冲，保证日志实时刷新。默认不输出颜色（CI/落盘场景无法渲染），
> 设置 `FORCE_COLOR` 环境变量可开启颜色；设置 `FMT_DEBUG=1` 会额外打印未识别的
> 事件类型（含截断后的事件原文）与混入的非 JSON 行，便于 qwen 升级后排查事件格式漂移。

脚本支持的环境变量：

| 环境变量            | 默认值   | 说明                                            |
|---------------------|----------|-------------------------------------------------|
| `FORCE_COLOR`       | 关闭     | 非空且非 `0` 时输出 ANSI 颜色                   |
| `FMT_DEBUG`         | 关闭     | 非空且非 `0` 时打印未识别事件原文与非 JSON 行   |
| `FMT_TEXT_LIMIT`    | `10000`  | 单条思考/回复正文的最大字符数, `0` 表示不限制   |
| `FMT_CONTENT_LINES` | `100`    | 工具结果/最终结果最多显示的行数, `0` 表示不限制 |
| `FMT_RAW_RESULT`    | 关闭     | 非空且非 `0` 时原样输出最终结果, 不折行         |
| `FMT_WIDTH`         | 终端宽度 | 渲染宽度, 取不到终端宽度时回退 `200`            |

## 扩展新场景

添加新场景只需两步：

1. 在 `modules/` 下创建安装脚本（可复用 `common.sh` 中的函数，由于 Git Bash 与 Linux bash 行为接近，扩展时几乎可照搬 Linux 版实现）
2. 创建对应的 `Dockerfile.{name}`，复制脚本并设置环境变量（`PATH`、`GITEA_RUNNER_LABELS_DEFAULT` 等），构建时通过 `C:\Program Files\Git\bin\bash.exe` 执行 .sh 脚本

## 自定义 CA 证书

容器启动时会自动导入自定义 CA 证书（在 Docker 守护进程启动前完成）。

将 PEM 格式的证书文件挂载到 `CA_CERT_DIR`（默认 `C:\certs`），启动时逐个导入：

- **系统侧**：通过 `certutil -addstore -f root` 导入到 Windows 根证书存储

```powershell
docker run -v C:\path\to\my-certs:C:\certs:ro ...
# 或自定义目录
docker run -e CA_CERT_DIR=C:\my-certs -v C:\path\to\my-certs:C:\my-certs:ro ...
```

> 证书文件应为 PEM 格式（以 `-----BEGIN CERTIFICATE-----` 开头）；所有文件按文件名排序导入。

## 主要环境变量

| 环境变量 | 默认值 | 说明 |
|---------|-------|------|
| `GITEA_INSTANCE_URL` | - | Gitea 实例地址（必填） |
| `GITEA_RUNNER_REGISTRATION_TOKEN` | - | 注册令牌（与 `GITEA_RUNNER_REGISTRATION_TOKEN_FILE` 二选一，直接提供时优先） |
| `GITEA_RUNNER_REGISTRATION_TOKEN_FILE` | - | 注册令牌文件路径（当 `GITEA_RUNNER_REGISTRATION_TOKEN` 为空时从此文件读取） |
| `GITEA_RUNNER_NAME` | - | Runner 名称 |
| `GITEA_RUNNER_LABELS` | `GITEA_RUNNER_LABELS_DEFAULT` | Runner 标签（逗号分隔） |
| `GITEA_RUNNER_TIMEOUT_MINUTES` | `60` | 容器空闲超时（分钟） |
| `GITEA_RUNNER_REGISTRATION_TIMEOUT` | `30` | 注册超时（秒） |
| `GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL` | `3` | 注册重试间隔（秒） |
| `INIT_SH_FILE` | - | 自定义初始化脚本路径（容器内，由 Git Bash `source` 执行） |
| `CA_CERT_DIR` | `C:\certs` | 自定义 CA 证书挂载目录 |
| `NPM_REGISTRY` | `https://mirrors.huaweicloud.com/repository/npm/` | NPM 镜像站 |
| `GITEA_RUNNER_CONFIG_TEMPLATE_FILE` | `C:\opt\config.template.yaml` | Runner 配置模板文件路径 |
