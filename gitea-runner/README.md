# gitea-runner 系列镜像

## 镜像结构

采用模块化设计，基础镜像（`gitea-runner`）包含通用运行时和 Docker 守护进程，各扩展镜像在此之上叠加特定场景的构建工具。

```
gitea-runner/                       ← 基础镜像 (Dockerfile)
├── Dockerfile                      # 基基础镜像
├── run.sh                          # 容器入口脚本（Docker 启动、Runner 注册、守护进程）
├── config.template.yaml            # Runner 配置文件模板（环境变量占位符）
├── modules/                        # 模块化安装脚本
│   ├── common.sh                   # 共享函数库 (curl 封装、架构检测、JDK/Maven/JMeter 安装)
│   ├── settings.xml                # Maven 阿里云镜像配置
│   ├── jdk21.sh                    # Temurin JDK 21 + Maven 3.9.9
│   ├── jdk25.sh                    # Temurin JDK 25 + Maven 3.9.9
│   ├── graalvm-jdk21.sh            # Oracle GraalVM JDK 21 + Maven 3.9.9
│   ├── graalvm-jdk25.sh            # Oracle GraalVM JDK 25 + Maven 3.9.9
│   └── jmeter.sh                   # Temurin JDK 25 + JMeter 5.6.3
├── Dockerfile.jdk21                # gitea-runner-jdk21
├── Dockerfile.jdk25                # gitea-runner-jdk25
├── Dockerfile.graalvm-jdk21        # gitea-runner-graalvm-jdk21
├── Dockerfile.graalvm-jdk25        # gitea-runner-graalvm-jdk25
├── Dockerfile.jmeter               # gitea-runner-jmeter
└── Dockerfile.flutter-ubuntu       # gitea-runner-flutter-ubuntu
```

## 镜像列表

| 镜像名称 | Dockerfile | 包含组件 | Runner 标签 |
|---------|-----------|---------|------------|
| `gitea-runner` | `Dockerfile` | Ubuntu 26.04 + Docker 28.5.2 + Gitea Runner 1.0.8 + Node.js 24.18.0 + Python 3 + 常用工具 | `ubuntu-latest,ubuntu-26.04` |
| `gitea-runner-jdk21` | `Dockerfile.jdk21` | + Temurin JDK 21 + Maven 3.9.9 | `ubuntu-latest,ubuntu-26.04,jdk-21` |
| `gitea-runner-jdk25` | `Dockerfile.jdk25` | + Temurin JDK 25 + Maven 3.9.9 | `ubuntu-latest,ubuntu-26.04,jdk-25` |
| `gitea-runner-graalvm-jdk21` | `Dockerfile.graalvm-jdk21` | + GraalVM JDK 21 + Maven 3.9.9 + gcc/g++/zlib1g-dev (native-image) | `ubuntu-latest,ubuntu-26.04,graalvm-jdk-21` |
| `gitea-runner-graalvm-jdk25` | `Dockerfile.graalvm-jdk25` | + GraalVM JDK 25 + Maven 3.9.9 + gcc/g++/zlib1g-dev (native-image) | `ubuntu-latest,ubuntu-26.04,graalvm-jdk-25` |
| `gitea-runner-jmeter` | `Dockerfile.jmeter` | + Temurin JDK 25 + JMeter 5.6.3 | `ubuntu-latest,ubuntu-26.04,jmeter` |
| `gitea-runner-flutter-ubuntu` | `Dockerfile.flutter-ubuntu` | + Flutter 3.44.2 + Android SDK (compileSdk 36, NDK 29, build-tools 36) + OpenJDK 21 | `ubuntu-latest,ubuntu-26.04,flutter-ubuntu` |

> 扩展镜像在基础标签之上追加各自的功能标签，无需重复声明基础标签。

## 本地构建

```bash
# 1. 先构建基础镜像
docker build -f gitea-runner/Dockerfile -t gitea-runner:base .

# 2. 构建扩展镜像（以 jdk21 为例）
docker build -f gitea-runner/Dockerfile.jdk21 --build-arg BASE_IMAGE=gitea-runner:base -t gitea-runner-jdk21:local .
```

## 工作原理

基础镜像已包含 Docker 守护进程和 Gitea Runner，扩展镜像在此基础上安装特定 JDK/Maven/JMeter 等工具。构建时通过 `ARG BASE_IMAGE` 引用基础镜像，无需手动处理任何依赖关系。

### 启动流程（`run.sh`）

容器启动时按顺序执行：

1. **打印启动横幅** — 显示 Runner 版本、时区、主机名、IP 及环境变量（敏感信息脱敏）
2. **导入自定义 CA 证书** — 在 Docker 守护进程启动前完成（见下文）
3. **配置国内镜像站** — APT / PIP / NPM（见下文）
4. **启动 Docker 守护进程** — 通过 `dind-hack` 配置嵌套环境，轮询等待引擎就绪
5. **加载自定义初始化脚本** — 若设置了 `INIT_SH_FILE` 则 source 执行
6. **渲染配置文件** — 从 `config.template.yaml` 模板用环境变量替换占位符
7. **注册 Runner** — 临时模式（`--ephemeral`），带超时重试（默认 30s 超时、3s 重试间隔）
8. **启动守护进程并监控** — 后台运行 `gitea-runner daemon`，主循环检测空闲超时

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

设置 `INIT_SH_FILE` 环境变量指向容器内脚本路径，启动时会 `source` 执行该脚本。

## 扩展新场景

添加新场景只需两步：

1. 在 `modules/` 下创建安装脚本（可复用 `common.sh` 中的函数）
2. 创建对应的 `Dockerfile.{name}`，复制脚本并设置环境变量（`JAVA_HOME`、`PATH`、`GITEA_RUNNER_LABELS_DEFAULT` 等）

## 国内镜像站配置

容器启动时自动配置国内镜像站（通过环境变量可覆盖默认值）：

| 镜像站 | 环境变量 | 默认值 |
|-------|---------|-------|
| Ubuntu APT | `APT_MIRROR_URI` | `https://mirrors.huaweicloud.com/ubuntu/` |
| Python PIP | `PIP_INDEX_URL` | `https://mirrors.huaweicloud.com/repository/pypi/simple` |
| Python PIP (信任主机) | `PIP_TRUSTED_HOST` | `mirrors.huaweicloud.com` |
| NPM | `NPM_REGISTRY` | `https://mirrors.huaweicloud.com/repository/npm/` |

Maven 镜像在构建时通过 `modules/settings.xml` 固定为阿里云公共仓库（`https://maven.aliyun.com/repository/public`），不可在运行时覆盖。

> APT 和 PIP 镜像仅在首次启动时配置（检测到已存在配置文件则跳过），可安全重启。NPM 镜像每次启动均刷新。

## 自定义 CA 证书

容器启动时会自动导入自定义 CA 证书（在 Docker 守护进程启动前完成，以便 dockerd 拉取 HTTPS 镜像时即可使用）。

### 使用方法

将 PEM 格式的证书文件挂载到 `CA_CERT_DIR`（默认 `/opt/cloud/security/cert/ca`），启动时逐个导入：

- **系统侧**：拷贝到 `/usr/local/share/ca-certificates/ca-{N}.crt` 后运行 `update-ca-certificates` 刷新 `/etc/ssl/certs/ca-certificates.crt`
- **Java 侧**：通过 `keytool` 导入到 `${JAVA_HOME}/lib/security/cacerts`（仅扩展镜像有 JAVA_HOME）

```bash
docker run -v /path/to/my-certs:/opt/cloud/security/cert/ca:ro ...
# 或自定义目录
docker run -e CA_CERT_DIR=/etc/my-certs -v /path/to/my-certs:/etc/my-certs:ro ...
```

> 证书文件应为 PEM 格式（以 `-----BEGIN CERTIFICATE-----` 开头）；所有文件按文件名排序导入，别名为 `ca-1`、`ca-2`...（storepass: `changeit`）。

## 主要环境变量

| 环境变量 | 默认值 | 说明 |
|---------|-------|------|
| `GITEA_INSTANCE_URL` | — | Gitea 实例地址（必填） |
| `GITEA_RUNNER_REGISTRATION_TOKEN` | — | 注册令牌（或通过文件提供） |
| `GITEA_RUNNER_NAME` | — | Runner 名称 |
| `GITEA_RUNNER_LABELS` | `GITEA_RUNNER_LABELS_DEFAULT` | Runner 标签（逗号分隔） |
| `GITEA_RUNNER_TIMEOUT_MINUTES` | `60` | 容器空闲超时（分钟） |
| `GITEA_RUNNER_REGISTRATION_TIMEOUT` | `30` | 注册超时（秒） |
| `GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL` | `3` | 注册重试间隔（秒） |
| `INIT_SH_FILE` | — | 自定义初始化脚本路径（容器内） |
| `CA_CERT_DIR` | `/opt/cloud/security/cert/ca` | 自定义 CA 证书挂载目录 |