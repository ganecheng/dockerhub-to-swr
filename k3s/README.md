# k3s

在 `gitea-runner` 基础上扩展的 CI 测试镜像，用于在同一个特权容器内运行：

- Docker Engine / Buildx / Compose
- 使用 Docker 作为容器引擎的单节点 k3s server
- Gitea Actions Runner

该镜像适合自托管、可信任务的集成测试环境，不适合运行不可信 PR。

## 运行要求

容器需要以特权模式运行，并建议挂载独立数据卷保存 runner、Docker 和 k3s 状态：

```bash
docker run --privileged --name k3s \
  -e GITEA_INSTANCE_URL=https://gitea.example.com \
  -e GITEA_RUNNER_REGISTRATION_TOKEN=replace-me \
  -e GITEA_RUNNER_NAME=k3s \
  -v k3s-data:/data \
  -v k3s-docker:/var/lib/docker \
  -v k3s-rancher:/var/lib/rancher/k3s \
  swr.cn-southwest-2.myhuaweicloud.com/gsc-hub/k3s:tag
```

## 默认行为

- 默认标签：`ubuntu-latest,ubuntu-26.04,k3s`
- 默认启动 k3s：`K3S_ENABLED=true`
- 默认让 k3s 使用 Docker 作为容器引擎：`K3S_USE_DOCKER=true`，启动时会追加 `--docker`。
- 默认禁用 k3s 的 `traefik`：`K3S_EXTRA_ARGS='--disable=traefik'`
- 默认保留 k3s 内置 `servicelb`，便于测试 `LoadBalancer` Service。
- 默认 kubeconfig：`/etc/rancher/k3s/k3s.yaml`
- 默认将任务容器网络设为 `host`，并只读挂载 kubeconfig，方便任务内 `kubectl` 访问本机 k3s API。

## 常用环境变量

- `K3S_ENABLED=false`：跳过 k3s 启动，仅作为 Docker-in-Docker runner 使用。
- `K3S_USE_DOCKER=false`：不追加 `--docker`，此时 k3s 会回到自身默认运行时；本镜像默认不使用该模式。
- `K3S_EXTRA_ARGS='...'`：追加 k3s server 启动参数，不需要在这里重复传入 `--docker`。
- `K3S_STARTUP_TIMEOUT=120`：等待 k3s 就绪的超时时间，单位秒。
- `K3S_KUBECONFIG_MODE=644`：kubeconfig 文件权限。
- `GITEA_RUNNER_JOB_CONTAINER_NETWORK=bridge`：如不希望任务容器使用 host 网络，可覆盖默认值，但需要自行处理 kubeconfig 中的 API 地址。
