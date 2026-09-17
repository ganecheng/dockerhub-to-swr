import sys
import os
import errno
import json
import shutil
import traceback
import unicodedata

TEXT_LIMIT    = 3000  # 单条思考/回复文本的最大字符数
CONTENT_LINES = 100   # 工具结果/最终结果最多显示的行数

# Colors for terminal output
C_THOUGHT = '\033[38;5;245m'
C_REPLY   = '\033[0;37m'
C_ACTION  = '\033[1;36m'
C_RESULT  = '\033[0;32m'
C_INFO    = '\033[1;34m'
C_ERR     = '\033[0;31m'
C_RESET   = '\033[0m'
C_DIM     = '\033[2m'

# 默认不输出颜色: 管道/CI 日志/tee 落盘等主流场景无法渲染 ANSI 转义,
# 需要颜色时设置 FORCE_COLOR 环境变量开启 (遵循 Node 生态约定, FORCE_COLOR=0 视为关闭)
if os.environ.get('FORCE_COLOR', '') in ('', '0'):
    C_THOUGHT = C_REPLY = C_ACTION = C_RESULT = C_INFO = C_ERR = C_RESET = C_DIM = ''

# 打印未识别的事件类型与非 JSON 行, 便于 qwen 升级后排查 stream-json 格式漂移
FMT_DEBUG = os.environ.get('FMT_DEBUG', '') not in ('', '0')

# Windows 管道下 Python 默认用 ANSI 代码页 (如 cp936) 收发字节,
# 会把 qwen 输出的 UTF-8 中文读成乱码、emoji 解码失败甚至崩溃,
# 因此强制 stdin/stdout 走 UTF-8, 不可解码字节替换为 U+FFFD;
# stdout 另外固定 newline='\n', 避免 Windows 下写出 CRLF 与容器内日志不一致
try:
    sys.stdin.reconfigure(encoding='utf-8', errors='replace')
except (AttributeError, ValueError, OSError):
    pass
try:
    sys.stdout.reconfigure(encoding='utf-8', errors='replace', newline='\n')
except (AttributeError, ValueError, OSError):
    pass

INDENT     = '    '          # 思考/回复正文的缩进
RESULT_PFX = '      │ '      # 工具结果每行的前缀
HDR_PROMPT = '👤 [用户提示词] '


def char_width(c):
    """单个字符的显示宽度: 组合符与变体选择符 0 列, CJK/emoji 2 列, 其余 1 列"""
    code = ord(c)
    if code in (0xFE0E, 0xFE0F) or code == 0x200D or unicodedata.combining(c):
        return 0
    if unicodedata.east_asian_width(c) in 'FW':
        return 2
    # emoji 的呈现宽度不在 east_asian_width 里: 🛠 (U+1F6E0) 记作 N(1 列),
    # 终端实际按 2 列渲染, 这里按 Unicode 区段兜底
    if 0x1F000 <= code <= 0x1FAFF or 0x2600 <= code <= 0x27BF:
        return 2
    return 1


def disp_width(s):
    return sum(char_width(c) for c in s)


def trunc(s, width):
    """按显示宽度截断 (CJK/全角/emoji 占 2 列), 超宽时补 ..."""
    width = max(4, width)  # 给 "..." 留出空间, 极窄宽度下也不会越界
    if disp_width(s) <= width:
        return s
    out, w = [], 3
    for c in s:
        cw = char_width(c)
        if w + cw > width:
            break
        out.append(c)
        w += cw
    return ''.join(out) + '...'


def wrap(s, width):
    """按显示宽度折行, 优先在空格处断开 (思考/回复正文折行而不是截断)"""
    width = max(8, width)
    out = []
    for raw in s.splitlines() or ['']:
        cur, cur_w = '', 0
        for c in raw:
            cw = char_width(c)
            if cur and cur_w + cw > width:
                sp = cur.rfind(' ')
                if sp > 0:
                    out.append(cur[:sp].rstrip())
                    cur = cur[sp + 1:]
                else:
                    out.append(cur)
                    cur = ''
                cur_w = disp_width(cur)
            cur += c
            cur_w += cw
        out.append(cur)
    return out


def collapse_blanks(text):
    """折叠连续空行 (思考/回复里的空行是段落分隔, 不能整行丢弃)"""
    out = []
    for ln in text.splitlines():
        if ln.strip():
            out.append(ln.rstrip())
        elif out and out[-1] != '':
            out.append('')
    while out and out[-1] == '':
        out.pop()
    return out


# 各类输出行的前缀 (图标+标签) 宽度不同, 预算按实际前缀算, 避免超宽折行或过度截断;
# 管道/CI 下取不到终端宽度时回退为 200 列
TERM_WIDTH = shutil.get_terminal_size((200, 24)).columns


def line_budget(prefix, minimum=40):
    """整行给到 TERM_WIDTH 时, 前缀之后还能容纳的显示宽度"""
    return max(minimum, TERM_WIDTH - disp_width(prefix))


W_PROMPT = line_budget(HDR_PROMPT)
W_TEXT   = line_budget(INDENT)
W_LINE   = line_budget(RESULT_PFX)


# result 事件子类型的中文说明 (未收录的原样输出)
SUBTYPE_CN = {
    'error_max_turns': '超出最大轮次',
    'error_during_execution': '执行出错',
}

# tool_use_id -> 该次调用的工具名/命令/是否已完整显示, 供 tool_result 标注与去重
TOOL_CALLS = {}
LAST_REPLY = {'text': '', 'full': False}


def p(s, end='\n'):
    print(s, end=end, flush=True)


def emit_lines(lines, color):
    """输出多行内容: 保留缩进, 按显示宽度截断, 行数超限折叠"""
    for ln in lines[:CONTENT_LINES]:
        p(f"{color}{RESULT_PFX}{trunc(ln.rstrip(), W_LINE)}{C_RESET}")
    if len(lines) > CONTENT_LINES:
        p(f"{color}{RESULT_PFX}... (还有 {len(lines) - CONTENT_LINES} 行){C_RESET}")


def emit_text(text, color):
    """输出思考/回复正文: 折叠连续空行, 长行按终端宽度折行"""
    for ln in collapse_blanks(text):
        for seg in wrap(ln, W_TEXT):
            p(f"{color}{INDENT}{seg}".rstrip() + C_RESET)


def describe_tool(name, inp):
    """把 tool_use 的输入压成一行摘要

    返回 (图标, 主文本, 不参与截断的后缀, 判断「已完整显示」的关键文本):
    主文本按剩余宽度截断, 后缀 (如 read_file 的行号范围) 永不截断;
    关键文本用于判断命令行是否完整可见 (命令后的描述被截掉不影响该判断)
    """
    if name == 'run_shell_command':
        cmd = str(inp.get('command') or '').replace('\r\n', '; ').replace('\n', '; ')
        desc = str(inp.get('description') or '')
        return '⚡', f"$ {cmd}" + (f"   # {desc}" if desc else ''), '', f"$ {cmd}"
    if name in ('read_file', 'write_file', 'edit'):
        icon = {'read_file': '📄', 'write_file': '📝', 'edit': '✏️'}[name]
        tail = ''
        if name == 'read_file' and inp.get('offset') is not None:
            tail = f" 第{inp.get('offset')}行起"
            if inp.get('limit') is not None:
                tail += f", 共{inp.get('limit')}行"
        fp = str(inp.get('file_path') or '')
        return icon, fp, tail, fp
    if name in ('grep_search', 'glob'):
        pat = str(inp.get('pattern') or inp.get('query') or '')
        where = inp.get('path') or inp.get('directory')
        main = pat + (f"   在 {where}" if where else '')
        return '🔍', main, '', main
    if name == 'web_fetch':
        url = str(inp.get('url') or '')
        return '🌐', url, '', url
    if name in ('agent', 'task'):
        desc = str(inp.get('description') or inp.get('subagent_type') or '')
        return '🤖', desc, '', desc
    if name == 'skill':
        sk = str(inp.get('skill') or '')
        return '🧩', sk, '', sk
    return '🛠️', str(inp), '', str(inp)


def strip_shell_echo(lines, call):
    """run_shell_command 结果开头的 Command:/Directory: 与工具行重复, 已完整显示时跳过"""
    if not lines or not call.get('shown_full'):
        return lines
    if lines[0] != f"Command: {call.get('command', '')}":
        return lines
    lines = lines[1:]
    if lines and lines[0].startswith('Directory: '):
        lines = lines[1:]
    return lines


def render_tool_result(block):
    call = TOOL_CALLS.get(block.get('tool_use_id')) or {}
    name = call.get('name')
    is_err = bool(block.get('is_error'))
    icon, color, title = ('❌', C_ERR, '[错误]') if is_err else ('✅', C_RESULT, '[结果]')
    p(f"{INDENT}{color}{icon} {title}{f' {name}' if name else ''}{C_RESET}")
    content = block.get('content')
    if content is None:
        return
    text = content if isinstance(content, str) else str(content)
    lines = text.rstrip().splitlines()
    if not is_err and name == 'run_shell_command':
        lines = strip_shell_echo(lines, call)
    emit_lines(lines, C_ERR if is_err else C_DIM)


def process(obj):
    t = obj.get('type', '')

    if t == 'system' and obj.get('subtype') == 'init':
        p(f"\n{C_INFO}🚀 [初始化] 模型={obj.get('model') or ''} "
          f"版本={obj.get('qwen_code_version') or ''} "
          f"权限模式={obj.get('permission_mode') or ''} "
          f"工作目录={obj.get('cwd') or ''}{C_RESET}")
        return

    if t == 'error':
        err = obj.get('error', '')
        if isinstance(err, dict):
            err = err.get('message', str(err))
        p(f"\n{C_ERR}🚨 [系统错误] {err}{C_RESET}")
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
            p(f"\n{C_INFO}{HDR_PROMPT}{trunc(first, W_PROMPT)}{C_RESET}")
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
        # 当前小节: 'thought' / 'reply' / None (工具行不切换小节)
        section = None
        for block in content:
            if not isinstance(block, dict):
                continue
            bt = block.get('type', '')
            if bt in ('text', 'thinking'):
                key = 'thinking' if bt == 'thinking' else 'text'
                text = block.get(key, '')
                if not isinstance(text, str) or not text.strip():
                    continue
                # text 是面向用户的回复, thinking 才是内部思考, 两者分开渲染,
                # 否则最终答案会被标成「思考」
                want = 'thought' if bt == 'thinking' else 'reply'
                if want != section:
                    if want == 'thought':
                        p(f"\n{C_THOUGHT}🧠 [思考]{C_RESET}")
                        color = C_THOUGHT
                    else:
                        p(f"\n{C_REPLY}💬 [回复]{C_RESET}")
                        color = C_REPLY
                    section = want
                else:
                    color = C_THOUGHT if want == 'thought' else C_REPLY
                if want == 'reply':
                    LAST_REPLY['text'] = text
                    LAST_REPLY['full'] = len(text) <= TEXT_LIMIT
                if len(text) > TEXT_LIMIT:
                    text = text[:TEXT_LIMIT] + ' ... (已截断)'
                emit_text(text, color)
            elif bt == 'tool_use':
                name = block.get('name', '')
                inp = block.get('input') or {}
                icon, main, tail, key = describe_tool(name, inp)
                # 前缀含缩进/图标/工具名, 主文本按剩余宽度截断, 后缀(如行号范围)不截断
                pfx = f"{INDENT}{icon} [{name}] "
                budget = line_budget(pfx + tail)
                p(f"{INDENT}{C_ACTION}{icon} [{name}]{C_RESET} {trunc(main, budget)}{tail}")
                TOOL_CALLS[block.get('id')] = {
                    'name': name,
                    'command': str(inp.get('command') or ''),
                    'shown_full': disp_width(key) <= budget,
                }
        return

    if t == 'result':
        # qwen 0.23.x 的 result 事件没有费用字段,
        # 展示轮次/耗时/token, 以及最终结果或错误信息
        is_err = bool(obj.get('is_error'))
        c, icon = (C_ERR, '❌') if is_err else (C_INFO, '🏁')
        info = [f"轮次={obj.get('num_turns', 0)}"]
        dur = obj.get('duration_ms')
        if isinstance(dur, (int, float)):
            api = obj.get('duration_api_ms')
            api_s = f" (API {api / 1000:.1f}秒)" if isinstance(api, (int, float)) else ''
            info.append(f"耗时={dur / 1000:.1f}秒{api_s}")
        usage = obj.get('usage')
        if isinstance(usage, dict):
            tin, tout = usage.get('input_tokens'), usage.get('output_tokens')
            if tin is not None or tout is not None:
                info.append(f"token={tin or 0}→{tout or 0}")
            if usage.get('cache_read_input_tokens'):
                info.append(f"缓存命中={usage['cache_read_input_tokens']}")
        subtype = obj.get('subtype')
        if subtype and subtype != 'success':
            info.append(f"({SUBTYPE_CN.get(subtype, subtype)})")
        p(f"\n{c}{icon} [结束] {' '.join(info)}{C_RESET}")
        denials = obj.get('permission_denials')
        if isinstance(denials, list) and denials:
            p(f"{INDENT}{C_ERR}⚠️  权限被拒 {len(denials)} 次{C_RESET}")
        if is_err:
            err = obj.get('error')
            msg = err.get('message') if isinstance(err, dict) else err
            if msg:
                emit_lines(str(msg).splitlines(), C_ERR)
        else:
            res = obj.get('result')
            if res:
                # 回复已完整打印过时, 最终结果不再重复一遍
                if LAST_REPLY['full'] and str(res).strip() == LAST_REPLY['text'].strip():
                    p(f"{C_DIM}{RESULT_PFX}(与上方 💬 [回复] 相同, 已省略){C_RESET}")
                else:
                    emit_lines(str(res).rstrip().splitlines(), C_DIM)
        return

    if FMT_DEBUG:
        p(f"\n{C_DIM}❔ [未识别事件] type={t or '-'} subtype={obj.get('subtype') or '-'}{C_RESET}")


for raw in sys.stdin:
    raw = raw.strip()
    if not raw:
        continue
    try:
        obj = json.loads(raw)
    except json.JSONDecodeError:
        # --debug 经 2>&1 混入的非 JSON 行 (如 "Debug mode enabled")
        if FMT_DEBUG:
            p(f"\n{C_DIM}❔ [非 JSON 行] {trunc(raw, line_budget('❔ [非 JSON 行] '))}{C_RESET}")
        continue
    try:
        process(obj)
    except OSError as e:
        # 下游 (head/grep -m 提前退出) 关闭了管道: Linux 抛 BrokenPipeError(EPIPE),
        # Windows 抛 OSError(EINVAL), 都要静默退出; 把 stdout 指向 devnull
        # 以免解释器退出时二次 flush 再报错
        if not isinstance(e, BrokenPipeError) and e.errno not in (errno.EPIPE, errno.EINVAL):
            traceback.print_exc()
            continue
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        sys.exit(0)
    except Exception:
        traceback.print_exc()
