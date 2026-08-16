#!/bin/bash

# -e当命令发生错误的时候, 停止脚本的执行;
set -ex

# 应用目录
cd /app

# 下载代码
git clone --filter=blob:none --no-checkout https://github.com/index-tts/index-tts.git .
git lfs install
git checkout v2.5.0
git lfs pull

git lfs uninstall && rm -rf .git

# 修复 BigVGAN 输出爆音：硬截断 → DC偏移消除 + 峰值归一化 + 安全截断
# 匹配 infer_v2.py (16空格缩进) 和 infer.py (12空格缩进)
python3 -c "
import re, pathlib

# (indent)wav = torch.clamp(32767 * wav, -32767.0, 32767.0)
pattern = re.compile(r'^(\s*)wav = torch\.clamp\(32767 \* wav, -32767\.0, 32767\.0\)$', re.MULTILINE)

replacement = r'''\1wav = wav - wav.mean(dim=-1, keepdim=True)
\1mx = wav.abs().max()
\1if mx > 0:
\1    wav = wav * (0.95 / mx)
\1wav = torch.clamp(32767 * wav, -32767.0, 32767.0)'''

for f in ['indextts/infer.py', 'indextts/infer_v2.py', 'indextts/infer_v2_5.py']:
    p = pathlib.Path(f)
    if not p.exists():
        continue
    content = p.read_text()
    new_content, count = pattern.subn(replacement, content)
    if count > 0:
        p.write_text(new_content)
        print(f'Patched {count} audio clamping line(s) in {f}')
    else:
        print(f'Pattern not found in {f}, skipping')
"

# 语言修改为默认中文
sed -i 's/.*getdefaultlocale.*/            language =\"zh_CN\"/' tools/i18n/i18n.py

# 移除pyproject.toml中基础镜像已提供的torch/torchaudio依赖
sed -i '/"torch==/d; /"torchaudio==/d' pyproject.toml

# 放宽 requires-python 上限，兼容未来系统 Python 版本
sed -i '/^requires-python/c\requires-python = ">=3.12"' pyproject.toml

# 移除 [tool.uv.sources] 及之后所有内容（pytorch-cuda源配置，已不需要）
sed -i '/^\[tool\.uv\.sources\]/,$d' pyproject.toml

# 删除 uv.lock，防止锁定的传递依赖（如torch）被强制安装
rm -f uv.lock

# 创建可访问系统包的虚拟环境，复用基础镜像已有的PyTorch
# 动态获取系统 Python 版本，确保 venv 与系统一致
PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
uv venv --python "$PY_VER" --system-site-packages

# 用 uv pip compile 生成完整锁定依赖列表，过滤掉基础镜像已提供的 PyTorch 系列包
# 这样 uv pip install 不会去下载 torch（避免了 uv sync 必然下载传递依赖的问题）
uv pip compile pyproject.toml --python "$PY_VER" --extra webui --no-annotate --no-header -o /tmp/requirements.txt
# 过滤掉 torch/torchaudio/nvidia-*/triton/cuda-* 系列（基础镜像已有）
grep -vE '^(torch|torchaudio|nvidia-|triton|cuda-bindings|cuda-pathfinder|cuda-toolkit)' /tmp/requirements.txt | grep -v '^#' > /tmp/requirements_filtered.txt
echo "=== 过滤后的依赖列表（已排除 PyTorch 系列）==="
cat /tmp/requirements_filtered.txt
echo ""
# --no-deps 关键：requirements_filtered.txt 已是完整展开的依赖树，无需再解析
uv pip install --no-deps -r /tmp/requirements_filtered.txt

# 兜底清理：万一有漏网之鱼，动态匹配所有 nvidia-* 包并卸载
uv pip list --format=freeze | grep -E '^(torch|torchaudio|nvidia-|triton|cuda-bindings|cuda-pathfinder|cuda-toolkit)==' | cut -d= -f1 | xargs -r uv pip uninstall --yes 2>/dev/null || true

# === 诊断：打印依赖来源，方便出错时确认问题边界 ===
echo "=== uv 管理的虚拟环境依赖 ==="
uv pip list
echo ""
echo "=== 系统 site-packages 中的 PyTorch 相关包 ==="
python -c "
import sys; sys.path = [p for p in sys.path if '.venv' not in p]
import subprocess; subprocess.run([sys.executable, '-m', 'pip', 'list', '--format=freeze'])
" 2>/dev/null || python -m pip list --format=freeze 2>/dev/null || true
echo ""
echo "=== 运行时实际解析的 torch 来源 ==="
python -c "import torch; print(f'torch={torch.__version__}  from {torch.__file__}')" 2>/dev/null || echo "torch 导入失败!"
python -c "import torchaudio; print(f'torchaudio={torchaudio.__version__}  from {torchaudio.__file__}')" 2>/dev/null || echo "torchaudio 导入失败!"
python -c "import triton; print(f'triton={triton.__version__}  from {triton.__file__}')" 2>/dev/null || echo "triton 导入失败!"
echo "=== 诊断结束 ==="

# 清理无用文件
sh /os_clean.sh