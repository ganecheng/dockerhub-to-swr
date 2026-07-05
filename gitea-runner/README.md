# gitea-runner 系列镜像

## 镜像结构

采用模块化设计，基础镜像（`gitea-runner`）包含通用运行时和 Docker 守护进程，各扩展镜像在此之上叠加特定场景的构建工具。

```
gitea-runner/               ← 基础镜像 (Dockerfile)
├── modules/                ← 模块化安装脚本
│   ├── common.sh           # 共享函数库 (curl封装、架构检测、安装函数)
│   ├── settings.xml        # Maven 阿里云镜像配置
│   ├── jdk21.sh           # Temurin JDK 21 + Maven
│   ├── jdk25.sh           # Temurin JDK 25 + Maven
│   ├── graalvm-jdk21.sh    # Oracle GraalVM JDK 21 + Maven
│   ├── graalvm-jdk25.sh    # Oracle GraalVM JDK 25 + Maven
│   └── jmeter.sh           # Temurin JDK 25 + JMeter
├── Dockerfile.jdk21       ← gitea-runner-jdk21
├── Dockerfile.jdk25       ← gitea-runner-jdk25
├── Dockerfile.graalvm-jdk21  ← gitea-runner-graalvm-jdk21
├── Dockerfile.graalvm-jdk25  ← gitea-runner-graalvm-jdk25
└── Dockerfile.jmeter       ← gitea-runner-jmeter
```

## 镜像列表

| 镜像名称 | Dockerfile | 包含组件 | Runner 标签 |
|---------|-----------|---------|------------|
| `gitea-runner` | `Dockerfile` | Ubuntu + Docker + Gitea Runner + 常用工具 | `ubuntu-latest,ubuntu-26.04` |
| `gitea-runner-jdk21` | `Dockerfile.jdk21` | + Temurin JDK 21 + Maven | `jdk-21` |
| `gitea-runner-jdk25` | `Dockerfile.jdk25` | + Temurin JDK 25 + Maven | `jdk-25` |
| `gitea-runner-graalvm-jdk21` | `Dockerfile.graalvm-jdk21` | + GraalVM JDK 21 + Maven | `graalvm-jdk-21` |
| `gitea-runner-graalvm-jdk25` | `Dockerfile.graalvm-jdk25` | + GraalVM JDK 25 + Maven | `graalvm-jdk-25` |
| `gitea-runner-jmeter` | `Dockerfile.jmeter` | + Temurin JDK 25 + JMeter | `jmeter` |

## 本地构建

```bash
# 1. 先构建基础镜像
docker build -f gitea-runner/Dockerfile -t gitea-runner:base .

# 2. 构建扩展镜像（以 jdk21 为例）
docker build -f gitea-runner/Dockerfile.jdk21 --build-arg BASE_IMAGE=gitea-runner:base -t gitea-runner-jdk21:local .
```

## 工作原理

基础镜像已包含 Docker 守护进程和 Gitea Runner，扩展镜像在此基础上安装特定 JDK/Maven/JMeter 等工具。构建时通过 `ARG BASE_IMAGE` 引用基础镜像，无需手动处理任何依赖关系。

## 扩展新场景

添加新场景只需两步：

1. 在 `modules/` 下创建安装脚本（可复用 `common.sh` 中的函数）
2. 创建对应的 `Dockerfile.{name}`，复制脚本并设置环境变量

## 自定义 CA 证书

容器启动时会自动导入自定义 CA 证书（在 Docker 守护进程启动前完成，以便 dockerd 拉取 HTTPS 镜像时即可使用）。

### 使用方法

将 PEM 格式的证书文件挂载到 `CA_CERT_DIR`（默认 `/opt/cloud/security/cert/ca`），启动时逐个导入：

- **系统侧**：拷贝到 `/usr/local/share/ca-certificates/` 后运行 `update-ca-certificates` 刷新 `/etc/ssl/certs/ca-certificates.crt`
- **Java 侧**：通过 `keytool` 导入到 `${JAVA_HOME}/lib/security/cacerts`（仅扩展镜像有 JAVA_HOME）

```bash
docker run -v /path/to/my-certs:/opt/cloud/security/cert/ca:ro ...
# 或自定义目录
docker run -e CA_CERT_DIR=/etc/my-certs -v /path/to/my-certs:/etc/my-certs:ro ...
```

> 证书文件应为 PEM 格式（以 `-----BEGIN CERTIFICATE-----` 开头）；所有文件按文件名顺序导入并赋予 `ca-1`、`ca-2`... 的别名。