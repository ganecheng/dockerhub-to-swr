import sys
import os
import json
import shutil
import traceback
import unicodedata

TEXT_LIMIT    = 3000  # 单条思考文本的最大字符数
CONTENT_LINES = 100   # 工具结果/最终结果最多显示的行数

# Colors for terminal output
C_THOUGHT = '\033[38;5;245m'
C_ACTION  = '\033[1;36m'
C_RESULT  = '\033[0;32m'
C_INFO    = '\033[1;34m'
C_ERR     = '\033[0;31m'
C_RESET   = '\033[0m'
C_DIM     = '\033[2m'

# 默认不输出颜色: 管道/CI 日志/tee 落盘等主流场景无法渲染 ANSI 转义,
# 需要颜色时设置 FORCE_COLOR 环境变量开启 (遵循 Node 生态约定, FORCE_COLOR=0 视为关闭)
if os.environ.get('FORCE_COLOR', '') in ('', '0'):
    C_THOUGHT = C_ACTION = C_RESULT = C_INFO = C_ERR = C_RESET = C_DIM = ''

# Windows 管道下 Python 默认用 ANSI 代码页 (如 cp936) 收发字节,
# 会把 qwen 输出的 UTF-8 中文读成乱码、emoji 解码失败甚至崩溃,
# 因此强制 stdin/stdout 走 UTF-8, 不可解码字节替换为 U+FFFD
for _stream in (sys.stdin, sys.stdout):
    try:
        _stream.reconfigure(encoding='utf-8', errors='replace')
    except (AttributeError, ValueError, OSError):
        pass

# 各类输出行的前缀 (图标+标签) 宽度不同, 按终端宽度分别预留开销;
# 管道/CI 下取不到终端宽度时回退为 200 列
TERM_WIDTH = shutil.get_terminal_size((200, 24)).columns
W_PROMPT = max(80, TERM_WIDTH - 25)   # 👤 [User Prompt]
W_CMD    = max(80, TERM_WIDTH - 20)   # ⚡ [Bash] $
W_LINE   = max(80, TERM_WIDTH - 15)   # 结果行 "      │ "


def p(s, end='\n'):
    print(s, end=end, flush=True)


def disp_width(s):
    return sum(2 if unicodedata.east_asian_width(c) in 'FW' else 1 for c in s)


def trunc(s, width):
    """按显示宽度截断 (CJK/全角占 2 列), 超宽时补 ..."""
    if disp_width(s) <= width:
        return s
    out, w = [], 3
    for c in s:
        cw = 2 if unicodedata.east_asian_width(c) in 'FW' else 1
        if w + cw > width:
            break
        out.append(c)
        w += cw
    return ''.join(out) + '...'


def emit_lines(lines, color):
    """输出多行内容: 保留缩进, 按显示宽度截断, 行数超限折叠"""
    for ln in lines[:CONTENT_LINES]:
        p(f"{color}      │ {trunc(ln.rstrip(), W_LINE)}{C_RESET}")
    if len(lines) > CONTENT_LINES:
        p(f"{color}      │ ... ({len(lines) - CONTENT_LINES} more lines){C_RESET}")


def render_tool_result(block):
    is_err = bool(block.get('is_error'))
    icon, color, title = ('❌', C_ERR, '[Error]') if is_err else ('✅', C_RESULT, '[Result]')
    p(f"{color}    {icon} {title}{C_RESET}")
    content = block.get('content')
    if content is None:
        return
    text = content if isinstance(content, str) else str(content)
    emit_lines(text.rstrip().splitlines(), C_ERR if is_err else C_DIM)


def process(obj):
    t = obj.get('type', '')

    if t == 'system' and obj.get('subtype') == 'init':
        p(f"\n{C_INFO}🚀 [Init] model={obj.get('model') or ''} "
          f"version={obj.get('qwen_code_version') or ''} cwd={obj.get('cwd') or ''}{C_RESET}")
        return

    if t == 'error':
        err = obj.get('error', '')
        if isinstance(err, dict):
            err = err.get('message', str(err))
        p(f"\n{C_ERR}🚨 [System Error] {err}{C_RESET}")
        return

    if t == 'user':
        msg = obj.get('message') or {}
        content = msg.get('content')
        if isinstance(content, str):
            content = [{'type': 'text', 'text': content}]
        if not isinstance(content, list):
            content = []
        text = ''.join(
            b.get('text', '') for b in content
            if isinstance(b, dict) and b.get('type') == 'text' and isinstance(b.get('text'), str)
        )
        if text.strip():
            first = text.strip().split('\n', 1)[0]
            p(f"\n{C_INFO}👤 [User Prompt] {trunc(first, W_PROMPT)}{C_RESET}")
        # qwen 0.23.x 的工具结果在 user 事件的 tool_result 内容块里,
        # 顶层没有 tool_use_result 字段
        for b in content:
            if isinstance(b, dict) and b.get('type') == 'tool_result':
                render_tool_result(b)
        return

    if t == 'assistant':
        msg = obj.get('message') or {}
        content = msg.get('content')
        if not isinstance(content, list):
            return
        has_thought = False
        for block in content:
            if not isinstance(block, dict):
                continue
            bt = block.get('type', '')
            if bt in ('text', 'thinking'):
                key = 'thinking' if bt == 'thinking' else 'text'
                text = block.get(key, '')
                if not isinstance(text, str) or not text.strip():
                    continue
                if len(text) > TEXT_LIMIT:
                    text = text[:TEXT_LIMIT] + ' ... (truncated)'
                if not has_thought:
                    p(f"\n{C_THOUGHT}🧠 [Thought]{C_RESET}")
                    has_thought = True
                for ln in text.splitlines():
                    if ln.strip():
                        p(f"{C_THOUGHT}    {ln}{C_RESET}")
            elif bt == 'tool_use':
                name = block.get('name', '')
                inp = block.get('input') or {}
                if name == 'Bash':
                    cmd = str(inp.get('command') or '').replace('\r\n', '; ').replace('\n', '; ')
                    p(f"    {C_ACTION}⚡ [{name}]{C_RESET} $ {trunc(cmd, W_CMD)}")
                elif name == 'Read':
                    rng = ''
                    if inp.get('offset') is not None:
                        rng = f" L{inp.get('offset')}"
                        if inp.get('limit') is not None:
                            rng += f"+{inp.get('limit')}"
                    fp = str(inp.get('file_path') or '')
                    p(f"    {C_ACTION}📄 [{name}]{C_RESET} {trunc(fp, W_CMD)}{rng}")
                else:
                    p(f"    {C_ACTION}🛠️  [{name}]{C_RESET} {trunc(str(inp), W_CMD)}")
        return

    if t == 'result':
        # qwen 0.23.x 的 result 事件没有费用字段,
        # 展示轮次/耗时/子类型, 以及最终结果或错误信息
        is_err = bool(obj.get('is_error'))
        c, icon = (C_ERR, '❌') if is_err else (C_INFO, '🏁')
        info = [f"turns={obj.get('num_turns', 0)}"]
        dur = obj.get('duration_ms')
        if isinstance(dur, (int, float)):
            info.append(f"{dur / 1000:.1f}s")
        subtype = obj.get('subtype')
        if subtype and subtype != 'success':
            info.append(subtype)
        p(f"\n{c}{icon} [结束 DONE] {' '.join(info)}{C_RESET}")
        if is_err:
            err = obj.get('error')
            msg = err.get('message') if isinstance(err, dict) else err
            if msg:
                emit_lines(str(msg).splitlines(), C_ERR)
        else:
            res = obj.get('result')
            if res:
                emit_lines(str(res).rstrip().splitlines(), C_DIM)
        return


for raw in sys.stdin:
    raw = raw.strip()
    if not raw:
        continue
    try:
        obj = json.loads(raw)
    except json.JSONDecodeError:
        continue  # --debug 经 2>&1 混入的非 JSON 行
    try:
        process(obj)
    except BrokenPipeError:
        # 下游 (head/grep -m/tee 提前退出) 关闭了管道, 静默退出;
        # 把 stdout 指向 devnull 以免解释器退出时二次 flush 再报错
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        sys.exit(0)
    except Exception:
        traceback.print_exc()
