# gitea-runner-ubuntu 系列镜像

## 镜像结构

采用模块化设计，基础镜像（`gitea-runner-ubuntu`）包含通用运行时和 Docker 守护进程，各扩展镜像在此之上叠加特定场景的构建工具。

```
gitea-runner-ubuntu/                ← 基础镜像 (Dockerfile)
├── Dockerfile                      # 基础镜像
├── run.sh                          # 容器入口脚本（Docker 启动、Runner 注册、守护进程）
├── config.template.yaml            # Runner 配置文件模板（环境变量占位符）
├── modules/                        # 模块化安装脚本
│   ├── common.sh                   # 共享函数库 (curl 封装、架构检测、JDK/Maven/JMeter 安装)
│   ├── settings.xml                # Maven 阿里云镜像配置
│   ├── jdk21.sh                    # Temurin JDK 21 + Maven 3.9.16
│   ├── jdk25.sh                    # Temurin JDK 25 + Maven 3.9.16
│   ├── graalvm-jdk21.sh            # Oracle GraalVM JDK 21 + Maven 3.9.16
│   ├── graalvm-jdk25.sh            # Oracle GraalVM JDK 25 + Maven 3.9.16
│   └── jmeter.sh                   # Temurin JDK 25 + JMeter 5.6.3
├── Dockerfile.jdk21                # gitea-runner-ubuntu-jdk21
├── Dockerfile.jdk25                # gitea-runner-ubuntu-jdk25
├── Dockerfile.graalvm-jdk21        # gitea-runner-ubuntu-graalvm-jdk21
├── Dockerfile.graalvm-jdk25        # gitea-runner-ubuntu-graalvm-jdk25
├── Dockerfile.jmeter               # gitea-runner-ubuntu-jmeter
└── Dockerfile.flutter              # gitea-runner-ubuntu-flutter
```

## 镜像列表

| 镜像名称                            | Dockerfile                 | 包含组件                                                                                                     | Runner 标签 (x86_64)                               | Runner 标签 (aarch64)                                                      |
|-------------------------------------|----------------------------|--------------------------------------------------------------------------------------------------------------|----------------------------------------------------|----------------------------------------------------------------------------|
| `gitea-runner-ubuntu`               | `Dockerfile`               | Ubuntu 26.04 + Docker 28.5.2 + Gitea Runner 3.5.0 + Node.js 24.21.0 + Qwen Code 0.24.3 + Python 3 + 常用工具 | `ubuntu-latest,ubuntu-26.04`                       | `ubuntu-aarch64-latest,ubuntu-aarch64-26.04`                               |
| `gitea-runner-ubuntu-jdk21`         | `Dockerfile.jdk21`         | + Temurin JDK 21 + Maven 3.9.16                                                                              | `ubuntu-latest,ubuntu-26.04,ubuntu-jdk-21`         | `ubuntu-aarch64-latest,ubuntu-aarch64-26.04,ubuntu-aarch64-jdk-21`         |
| `gitea-runner-ubuntu-jdk25`         | `Dockerfile.jdk25`         | + Temurin JDK 25 + Maven 3.9.16                                                                              | `ubuntu-latest,ubuntu-26.04,ubuntu-jdk-25`         | `ubuntu-aarch64-latest,ubuntu-aarch64-26.04,ubuntu-aarch64-jdk-25`         |
| `gitea-runner-ubuntu-graalvm-jdk21` | `Dockerfile.graalvm-jdk21` | + GraalVM JDK 21 + Maven 3.9.16 + gcc/g++/zlib1g-dev (native-image)                                          | `ubuntu-latest,ubuntu-26.04,ubuntu-graalvm-jdk-21` | `ubuntu-aarch64-latest,ubuntu-aarch64-26.04,ubuntu-aarch64-graalvm-jdk-21` |
| `gitea-runner-ubuntu-graalvm-jdk25` | `Dockerfile.graalvm-jdk25` | + GraalVM JDK 25 + Maven 3.9.16 + gcc/g++/zlib1g-dev (native-image)                                          | `ubuntu-latest,ubuntu-26.04,ubuntu-graalvm-jdk-25` | `ubuntu-aarch64-latest,ubuntu-aarch64-26.04,ubuntu-aarch64-graalvm-jdk-25` |
| `gitea-runner-ubuntu-jmeter`        | `Dockerfile.jmeter`        | + Temurin JDK 25 + JMeter 5.6.3                                                                              | `ubuntu-latest,ubuntu-26.04,ubuntu-jmeter`         | `ubuntu-aarch64-latest,ubuntu-aarch64-26.04,ubuntu-aarch64-jmeter`         |
| `gitea-runner-ubuntu-flutter`       | `Dockerfile.flutter`       | + Flutter 3.44.9 + Android SDK (compileSdk 36, NDK 29, build-tools 36) + OpenJDK 21                          | `ubuntu-latest,ubuntu-26.04,ubuntu-flutter`        | 仅 x86_64                                                                  |

> 扩展镜像在基础标签之上追加各自的功能标签，无需重复声明基础标签。
> Runner 标签为 `GITEA_RUNNER_LABELS_DEFAULT` 的默认值，已按架构分列；flutter 扩展仅提供 x86_64 版本。

## 镜像架构

基础镜像与各扩展镜像同时构建 x86_64 与 aarch64 两种架构，通过 tag 后缀区分，
aarch64 版本在 GitHub 托管的 ARM64 runner（`ubuntu-26.04-arm`）上原生构建：

| 架构    | tag 后缀   |
|---------|------------|
| x86_64  | `-x86_64`  |
| aarch64 | `-aarch64` |

Runner 默认标签（`GITEA_RUNNER_LABELS_DEFAULT`）随架构变化，避免 Gitea
调度时把任务分配到错误架构的 Runner：

- x86_64 镜像：`ubuntu-latest,ubuntu-26.04`
- aarch64 镜像：`ubuntu-aarch64-latest,ubuntu-aarch64-26.04`

扩展镜像在此基础上追加各自的功能标签（如 jdk21 的 `ubuntu-jdk-21`，
aarch64 镜像对应为 `ubuntu-aarch64-jdk-21`）。

> `flutter` 扩展仅提供 x86_64 版本：Flutter 官方未发布 linux-arm64 的 Dart SDK
> 与 Android 构建工具链二进制。

## 本地构建

```bash
# 1. 先构建基础镜像（默认 x86_64）
docker build -f gitea-runner-ubuntu/Dockerfile -t gitea-runner-ubuntu:base .

# 2. 构建扩展镜像（以 jdk21 为例）
docker build -f gitea-runner-ubuntu/Dockerfile.jdk21 --build-arg BASE_IMAGE=gitea-runner-ubuntu:base -t gitea-runner-ubuntu-jdk21:local .

# 3. 构建 aarch64 版本（在 ARM 机器上原生构建，或配合 buildx --platform linux/arm64）
docker build -f gitea-runner-ubuntu/Dockerfile --build-arg BASE_ARCH=aarch64 --build-arg ARCH_SUFFIX=-aarch64 -t gitea-runner-ubuntu:base-arm .
docker build -f gitea-runner-ubuntu/Dockerfile.jdk21 --build-arg BASE_IMAGE=gitea-runner-ubuntu:base-arm --build-arg ARCH_SUFFIX=-aarch64 -t gitea-runner-ubuntu-jdk21:local-arm .
```

## 工作原理

基础镜像已包含 Docker 守护进程和 Gitea Runner，扩展镜像在此基础上安装特定 JDK/Maven/JMeter 等工具。构建时通过
`ARG BASE_IMAGE` 引用基础镜像，无需手动处理任何依赖关系。

### 启动流程（`run.sh`）

容器启动时按顺序执行：

1. **打印启动横幅** - 显示 Runner 版本、时区、主机名、IP 及环境变量（敏感信息脱敏）
2. **导入自定义 CA 证书** - 在 Docker 守护进程启动前完成（见下文）
3. **配置国内镜像站** - APT / PIP / NPM（见下文）
4. **启动 Docker 守护进程** - 通过 `dind-hack` 配置嵌套环境，轮询等待引擎就绪
5. **加载自定义初始化脚本** - 若设置了 `INIT_SH_FILE` 则 source 执行
6. **渲染配置文件** - 从 `config.template.yaml` 模板用环境变量替换占位符
7. **注册 Runner** - 临时模式（`--ephemeral`），带超时重试（默认 30s 超时、3s 重试间隔）
8. **启动守护进程并监控** - 后台运行 `gitea-runner daemon`，主循环检测空闲超时

### 临时模式与空闲超时

Runner 以 **ephemeral 模式**运行：完成一个任务后自动退出，容器随之销毁。

容器空闲超时由 `GITEA_RUNNER_TIMEOUT_MINUTES`（默认 `60`）控制。启动时计算 deadline，任务被接收后 deadline
刷新，确保任务有充足执行时间。超时后容器自动退出。

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

设置 `INIT_SH_FILE` 环境变量指向容器内脚本路径，启动时会 `source` 执行该脚本。

## 内置 Qwen Code CLI

基础镜像通过 npm 全局安装 Qwen Code CLI（当前 `0.24.3`，可用构建参数
`QWEN_CODE_VERSION` 覆盖版本），并内置流式输出格式化脚本：仓库内 `common/fmt_stream.py`
（两个 Runner 镜像共用同一份），镜像内为 `/opt/fmt_stream.py`。

qwen 以 `--output-format stream-json` 运行时，每行输出一个 JSON 事件，直接查看可读性差。
`fmt_stream.py` 会将 JSON 流渲染为带颜色的日志（思考、回复、工具调用、执行结果）：
思考与回复正文按终端宽度折行（续行额外缩进两列，与原文换行区分；Markdown 表格行不折行，以免
复制出去不再是合法表格），工具结果按终端宽度截断。子智能体（agent/Task）的消息整体缩进一层
并带 `↳` 标记，与主智能体的输出区分；初始化行附会话号（对应 `--debug` 日志文件名）、MCP
服务器清单与目标状态变化各占一行。最终结果整篇只打印一次——与最后一条回复重复时折叠为一行
提示，回复曾被截断时只补打剩余部分。

```bash
timeout 3600 \
  qwen --debug --output-format stream-json --yolo -p "任务描述" \
  2>&1 | tee result.txt | python3 -u /opt/fmt_stream.py | tee pretty.txt
```

> 脚本仅依赖 Python 3 标准库，镜像已自带 `python3`；需通过 `python3 -u` 调用
> 以关闭输出缓冲，保证日志实时刷新。默认不输出颜色（CI/落盘场景无法渲染），
> 设置 `FORCE_COLOR` 环境变量可开启颜色；设置 `FMT_DEBUG=1` 会额外打印未识别的
> 事件类型（含截断后的事件原文）与混入的非 JSON 行，便于 qwen 升级后排查事件格式漂移。
> Windows 版镜像的等价脚本位于 `C:\opt\bin\fmt_stream.py`（见 [gitea-runner-windows](../gitea-runner-windows/README.md)）。

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

1. 在 `modules/` 下创建安装脚本（可复用 `common.sh` 中的函数）
2. 创建对应的 `Dockerfile.{name}`，复制脚本并设置环境变量（`JAVA_HOME`、`PATH`、`GITEA_RUNNER_LABELS_DEFAULT` 等）

## 国内镜像站配置

容器启动时自动配置国内镜像站（通过环境变量可覆盖默认值）：

| 镜像站                | 环境变量           | 默认值                                                   |
|-----------------------|--------------------|----------------------------------------------------------|
| Ubuntu APT            | `APT_MIRROR_URI`   | `https://mirrors.huaweicloud.com/ubuntu/`                |
| Python PIP            | `PIP_INDEX_URL`    | `https://mirrors.huaweicloud.com/repository/pypi/simple` |
| Python PIP (信任主机) | `PIP_TRUSTED_HOST` | `mirrors.huaweicloud.com`                                |
| NPM                   | `NPM_REGISTRY`     | `https://mirrors.huaweicloud.com/repository/npm/`        |

Maven 镜像在构建时通过 `modules/settings.xml`
固定为阿里云公共仓库（`https://maven.aliyun.com/repository/public`），不可在运行时覆盖。

> APT 和 PIP 镜像仅在首次启动时配置（检测到已存在配置文件则跳过），可安全重启。NPM 镜像每次启动均刷新。

## 自定义 CA 证书

容器启动时会自动导入自定义 CA 证书（在 Docker 守护进程启动前完成，以便 dockerd 拉取 HTTPS 镜像时即可使用）。

### 使用方法

将 PEM 格式的证书文件挂载到 `CA_CERT_DIR`（默认 `/opt/cloud/security/cert/ca`），启动时逐个导入：

- **系统侧**：拷贝到 `/usr/local/share/ca-certificates/ca-{N}.crt` 后运行 `update-ca-certificates` 刷新
  `/etc/ssl/certs/ca-certificates.crt`
- **Java 侧**：通过 `keytool` 导入到 `${JAVA_HOME}/lib/security/cacerts`（仅扩展镜像有 JAVA_HOME）

```bash
docker run -v /path/to/my-certs:/opt/cloud/security/cert/ca:ro ...
# 或自定义目录
docker run -e CA_CERT_DIR=/etc/my-certs -v /path/to/my-certs:/etc/my-certs:ro ...
```

> 证书文件应为 PEM 格式（以 `-----BEGIN CERTIFICATE-----` 开头）；所有文件按文件名排序导入，别名为 `ca-1`、`ca-2`
> ...（storepass: `changeit`）。

## 主要环境变量

| 环境变量                                   | 默认值                                                   | 说明                                                                         |
|--------------------------------------------|----------------------------------------------------------|------------------------------------------------------------------------------|
| `GITEA_INSTANCE_URL`                       | -                                                        | Gitea 实例地址（必填）                                                       |
| `GITEA_RUNNER_REGISTRATION_TOKEN`          | -                                                        | 注册令牌（与 `GITEA_RUNNER_REGISTRATION_TOKEN_FILE` 二选一，直接提供时优先） |
| `GITEA_RUNNER_REGISTRATION_TOKEN_FILE`     | -                                                        | 注册令牌文件路径（当 `GITEA_RUNNER_REGISTRATION_TOKEN` 为空时从此文件读取）  |
| `GITEA_RUNNER_NAME`                        | -                                                        | Runner 名称                                                                  |
| `GITEA_RUNNER_LABELS`                      | `GITEA_RUNNER_LABELS_DEFAULT`                            | Runner 标签（逗号分隔）                                                      |
| `GITEA_RUNNER_TIMEOUT_MINUTES`             | `60`                                                     | 容器空闲超时（分钟）                                                         |
| `GITEA_RUNNER_REGISTRATION_TIMEOUT`        | `30`                                                     | 注册超时（秒）                                                               |
| `GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL` | `3`                                                      | 注册重试间隔（秒）                                                           |
| `INIT_SH_FILE`                             | -                                                        | 自定义初始化脚本路径（容器内）                                               |
| `CA_CERT_DIR`                              | `/opt/cloud/security/cert/ca`                            | 自定义 CA 证书挂载目录                                                       |
| `GITEA_RUNNER_CONFIG_TEMPLATE_FILE`        | `/opt/config.template.yaml`                              | Runner 配置模板文件路径                                                      |
| `APT_MIRROR_URI`                           | `https://mirrors.huaweicloud.com/ubuntu/`                | Ubuntu APT 镜像站                                                            |
| `PIP_INDEX_URL`                            | `https://mirrors.huaweicloud.com/repository/pypi/simple` | Python PIP 镜像站                                                            |
| `PIP_TRUSTED_HOST`                         | `mirrors.huaweicloud.com`                                | PIP 信任主机                                                                 |
| `NPM_REGISTRY`                             | `https://mirrors.huaweicloud.com/repository/npm/`        | NPM 镜像站                                                                   |
