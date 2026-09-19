# common

两个 Runner 镜像共用的资源目录，目前只有 `fmt_stream.py`：把 qwen
`--output-format stream-json` 的日志渲染成带缩进与颜色（思考、回复、工具调用、
执行结果）的脚本。本目录是唯一维护点，两个镜像各自 COPY 一份进镜像：
`gitea-runner-ubuntu` 为 `/opt/fmt_stream.py`，`gitea-runner-windows` 为
`C:\opt\bin\fmt_stream.py`。

## 验证渲染结果

`result.txt` 是 qwen 的原始 stream-json 输出，`pretty.txt` 是格式化后的日志，
两者由「完整实时管道」一节产生；拿到任意一份 `result.txt` 都可以用下面的命令
离线重放。

命令按 Git Bash 写，本机用 `python`（Windows 上 `python3` 常只是应用商店占位符，
不可用）；容器内换成 `python3`、脚本路径见下面的容器小节。PowerShell 不支持 `<`
输入重定向，需改用 `Get-Content result.txt | python -u common/fmt_stream.py`。

### 离线重放（最常用）

```bash
python -u common/fmt_stream.py < result.txt | tee pretty.txt
```

### 带颜色查看

```bash
FORCE_COLOR=1 python -u common/fmt_stream.py < result.txt | less -R
```

### 指定渲染宽度（模拟 CI 日志查看器）

```bash
FMT_WIDTH=80 python -u common/fmt_stream.py < result.txt | less
```

### 只看交付物原文（不折行、不加前缀，便于管道给下游）

```bash
FMT_RAW_RESULT=1 python -u common/fmt_stream.py < result.txt | tail -n 25
```

### 排查事件格式漂移（未识别事件与非 JSON 行）

```bash
FMT_DEBUG=1 python -u common/fmt_stream.py < result.txt | grep -n '❔'
```

> 没有输出即没有未识别事件与非 JSON 行，属正常。

### 在 Runner 容器内重放

```bash
python3 -u /opt/fmt_stream.py < result.txt | tee pretty.txt
```

```bash
python3 -u "C:/opt/bin/fmt_stream.py" < result.txt | tee pretty.txt
```

## 完整实时管道

在容器内跑真实任务时使用（本机演练把脚本路径换成 `common/fmt_stream.py`、
`python3` 换成 `python`）：

```bash
timeout 3600 \
  qwen --debug --output-format stream-json --yolo -p "任务描述" \
  2>&1 | tee result.txt | python3 -u /opt/fmt_stream.py | tee pretty.txt
```

环境变量（`FMT_*`、`FORCE_COLOR`）与渲染规则见
[gitea-runner-ubuntu/README.md](../gitea-runner-ubuntu/README.md) 与
[gitea-runner-windows/README.md](../gitea-runner-windows/README.md) 的「内置
Qwen Code CLI」一节。
