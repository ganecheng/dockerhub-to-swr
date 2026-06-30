# k3s

面向 k3s 测试和实验场景的镜像，用于在同一个特权容器内运行：

- Docker Engine / Buildx / Compose
- 使用 Docker 作为容器引擎的单节点 k3s server

该镜像定位为 k3s 镜像。

## 运行要求

容器需要以特权模式运行，并建议挂载独立数据卷保存 Docker 和 k3s 状态：

```bash
docker run --privileged --name k3s \
  -v k3s-docker:/var/lib/docker \
  -v k3s-rancher:/var/lib/rancher/k3s \
  swr.cn-southwest-2.myhuaweicloud.com/gsc-hub/k3s:tag
```

启动后可以在容器内使用 Docker 和 kubectl：

```bash
docker exec k3s docker info
docker exec k3s kubectl get nodes -o wide
```

## 默认行为

- 默认启动 k3s：`K3S_ENABLED=true`
- 默认让 k3s 使用 Docker 作为容器引擎：`K3S_USE_DOCKER=true`，启动时会追加 `--docker`。
- 默认禁用 k3s 的 `traefik`：`K3S_EXTRA_ARGS='--disable=traefik'`
- 默认保留 k3s 内置 `servicelb`，便于测试 `LoadBalancer` Service。
- 默认 kubeconfig：`/etc/rancher/k3s/k3s.yaml`

## 常用环境变量

- `K3S_ENABLED=false`：跳过 k3s 启动，仅启动 Docker-in-Docker。
- `K3S_USE_DOCKER=false`：不追加 `--docker`，此时 k3s 会回到自身默认运行时；本镜像默认不使用该模式。
- `K3S_EXTRA_ARGS='...'`：追加 k3s server 启动参数，不需要在这里重复传入 `--docker`。
- `K3S_STARTUP_TIMEOUT=120`：等待 k3s 就绪的超时时间，单位秒。
- `K3S_KUBECONFIG_MODE=644`：kubeconfig 文件权限。
- `INIT_SH_FILE=/path/to/init.sh`：在 Docker 和 k3s 启动完成后加载自定义初始化脚本。
