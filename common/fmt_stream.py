import sys
import os
import errno
import json
import re
import shutil
import traceback
import unicodedata


def env_int(name, default, minimum=0):
    """读取整数环境变量, 缺失/非法/越界时回退默认值"""
    try:
        value = int(os.environ.get(name, ''))
    except ValueError:
        return default
    return value if value >= minimum else default


# 阈值均可用环境变量覆盖: CI/落盘场景想要完整日志时调大, 或置 0 表示不限制
TEXT_LIMIT    = env_int('FMT_TEXT_LIMIT', 10000, 0)   # 单条思考/回复文本的最大字符数
CONTENT_LINES = env_int('FMT_CONTENT_LINES', 100, 0)  # 工具结果/最终结果最多显示的行数

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

INDENT      = '    '         # 思考/回复正文的缩进
CONT_INDENT = '  '           # 折行续行的额外缩进, 用来与原文换行区分
RESULT_PFX  = '      │ '     # 工具结果每行的前缀
HDR_PROMPT  = '👤 [用户提示词] '

# 工具/模型输出里可能混入 ANSI 颜色与制表符: 制表符按 1 列测量与实际显示 (跳到
# 制表位) 不符, 内嵌的 \x1b[0m 还会关掉本脚本给该行设的颜色, 因此统一先归一化
ANSI_RE = re.compile(r'\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b[@-Z\\-_]')


def plain(s, tab=4):
    """剥离 ANSI 颜色序列并展开制表符, 保证测量宽度与实际显示一致"""
    return ANSI_RE.sub('', s).expandtabs(tab)


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
    """按显示宽度折行, 优先在空格处断开 (思考/回复正文折行而不是截断)

    续行加上 CONT_INDENT 缩进, 让折行与原文换行在视觉上可区分; 续行可用宽度
    相应减去该缩进, 保证折行后整行仍不超预算
    """
    width = max(8, width)
    cont_w = disp_width(CONT_INDENT)
    out = []
    for raw in s.splitlines() or ['']:
        cur, cur_w, budget, indent = '', 0, width, ''
        for c in raw:
            cw = char_width(c)
            if cur and cur_w + cw > budget:
                sp = cur.rfind(' ')
                if sp > 0:
                    out.append(indent + cur[:sp].rstrip())
                    cur = cur[sp + 1:]
                else:
                    out.append(indent + cur)
                    cur = ''
                cur_w = disp_width(cur)
                budget, indent = max(8, width - cont_w), CONT_INDENT
            cur += c
            cur_w += cw
        out.append(indent + cur)
    return out


def collapse_blanks(text):
    """折叠连续空行并归一化 (思考/回复里的空行是段落分隔, 不能整行丢弃)"""
    out = []
    for ln in text.splitlines():
        ln = plain(ln)
        if ln.strip():
            out.append(ln.rstrip())
        elif out and out[-1] != '':
            out.append('')
    while out and out[-1] == '':
        out.pop()
    return out


# 各类输出行的前缀 (图标+标签) 宽度不同, 预算按实际前缀算, 避免超宽折行或过度截断;
# 管道/CI 下取不到终端宽度时回退为 200 列, FMT_WIDTH 可显式覆盖
TERM_WIDTH = env_int('FMT_WIDTH', shutil.get_terminal_size((200, 24)).columns, 20)


def line_budget(prefix, minimum=40):
    """整行给到 TERM_WIDTH 时, 前缀之后还能容纳的显示宽度"""
    return max(minimum, TERM_WIDTH - disp_width(prefix))


W_PROMPT = line_budget(HDR_PROMPT)
W_LINE   = line_budget(RESULT_PFX)
W_DEBUG  = line_budget('❔ [未识别事件] ')


# result 事件子类型的中文说明 (未收录的原样输出)
SUBTYPE_CN = {
    'error_max_turns': '超出最大轮次',
    'error_during_execution': '执行出错',
}

# tool_use_id -> 该次调用的工具名/命令/是否已完整显示, 供 tool_result 标注与去重
TOOL_CALLS = {}
# 最后一条回复的全文, 以及其中已被完整显示的字符数 (供 result 事件去重)
LAST_REPLY = {'text': '', 'shown': 0}


def p(s, end='\n'):
    print(s, end=end, flush=True)


def emit_lines(lines, color):
    """输出工具结果: 保留缩进, 按显示宽度截断, 行数超限折叠"""
    limit = CONTENT_LINES or len(lines)
    for ln in lines[:limit]:
        p(f"{color}{RESULT_PFX}{trunc(plain(ln).rstrip(), W_LINE)}{C_RESET}")
    if len(lines) > limit:
        p(f"{color}{RESULT_PFX}... (还有 {len(lines) - limit} 行){C_RESET}")


def emit_text(text, color, prefix=INDENT, limit=0):
    """输出思考/回复/最终结果正文: 折叠连续空行, 长行折行 (不丢字符)"""
    lines = collapse_blanks(text)
    limit = limit or len(lines)
    for ln in lines[:limit]:
        for seg in wrap(ln, line_budget(prefix)):
            p(f"{color}{prefix}{seg}".rstrip() + C_RESET)
    if len(lines) > limit:
        p(f"{color}{prefix}... (还有 {len(lines) - limit} 行){C_RESET}")


def brief(value, width=60):
    """兜底摘要里的值: 容器只报元素/键个数, 长值截断并压成单行, 避免 Python repr"""
    if isinstance(value, dict):
        return f"{{{len(value)} 键}}"
    if isinstance(value, (list, tuple)):
        return f"[{len(value)} 项]"
    return trunc(' '.join(str(value).split()), width)


def compact(inp):
    """把未收录工具的输入压成 k=v 一行摘要"""
    return ' '.join(
        f"{k}={brief(v)}" for k, v in inp.items()
        if v not in (None, '', [], {})
    )


def describe_tool(name, inp):
    """把 tool_use 的输入压成一行摘要

    返回 (图标, 主文本, 不参与截断的后缀, 判断「已完整显示」的关键文本):
    主文本按剩余宽度截断, 后缀 (如 read_file 的行号范围) 永不截断;
    关键文本用于判断命令行是否完整可见 (命令后的描述被截掉不影响该判断)
    """
    if not isinstance(inp, dict):
        # 输入形态异常时不能因属性缺失丢掉整条事件
        text = brief(inp)
        return '🛠️', text, '', text
    if name in ('run_shell_command', 'monitor'):
        cmd = str(inp.get('command') or '').replace('\r\n', '; ').replace('\n', '; ')
        desc = str(inp.get('description') or '')
        return '⚡', f"$ {cmd}" + (f"   # {desc}" if desc else ''), '', f"$ {cmd}"
    if name in ('read_file', 'write_file', 'edit', 'notebook_edit'):
        icon = {'read_file': '📄', 'write_file': '📝',
                'edit': '✏️', 'notebook_edit': '📓'}[name]
        tail = ''
        if name == 'read_file' and inp.get('offset') is not None:
            tail = f" 第{inp.get('offset')}行起"
            if inp.get('limit') is not None:
                tail += f", 共{inp.get('limit')}行"
        fp = str(inp.get('file_path') or inp.get('notebook_path') or '')
        if name == 'notebook_edit' and inp.get('cell_id'):
            fp += f" cell={inp.get('cell_id')}"
        return icon, fp, tail, fp
    if name in ('grep_search', 'glob'):
        pat = str(inp.get('pattern') or inp.get('query') or '')
        where = inp.get('path') or inp.get('directory')
        main = pat + (f"   在 {where}" if where else '')
        return '🔍', main, '', main
    if name == 'web_fetch':
        url = str(inp.get('url') or '')
        return '🌐', url, '', url
    if name == 'read_mcp_resource':
        main = f"{inp.get('server_name') or ''}:{inp.get('uri') or ''}"
        return '🔌', main, '', main
    if name in ('agent', 'task'):
        desc = str(inp.get('description') or inp.get('subagent_type') or '')
        return '🤖', desc, '', desc
    if name == 'skill':
        sk = str(inp.get('skill') or '')
        return '🧩', sk, '', sk
    if name == 'record_artifact':
        main = str(inp.get('title') or inp.get('workspacePath') or inp.get('url') or '')
        return '📦', main, '', main
    if name == 'send_message':
        main = str(inp.get('to') or inp.get('task_id') or '')
        return '✉️', main, '', main
    text = compact(inp)
    return '🛠️', text, '', text


def strip_shell_echo(lines, call):
    """run_shell_command 结果开头的 Command:/Directory: 与工具行重复, 已完整显示时跳过

    命令可能含换行, 因此按「Command: + 完整命令行」整体比较, 而不是只比首行
    """
    if not lines or not call.get('shown_full'):
        return lines
    expect = f"Command: {call.get('command', '')}".splitlines()
    if lines[:len(expect)] != expect:
        return lines
    lines = lines[len(expect):]
    if lines and lines[0].startswith('Directory: '):
        lines = lines[1:]
    return lines


def content_text(content):
    """把 tool_result 的 content 归一成文本: 字符串原样, 内容块列表取 text 块拼接"""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = [b.get('text', '') for b in content
                 if isinstance(b, dict) and isinstance(b.get('text'), str)]
        if parts:
            return '\n'.join(parts)
    return str(content)


def render_tool_result(block):
    call = TOOL_CALLS.get(block.get('tool_use_id')) or {}
    name = call.get('name')
    is_err = bool(block.get('is_error'))
    icon, color, title = ('❌', C_ERR, '[错误]') if is_err else ('✅', C_RESULT, '[结果]')
    p(f"{INDENT}{color}{icon} {title}{f' {name}' if name else ''}{C_RESET}")
    content = block.get('content')
    if content is None:
        return
    lines = content_text(content).rstrip().splitlines()
    if not is_err and name == 'run_shell_command':
        lines = strip_shell_echo(lines, call)
    emit_lines(lines, C_ERR if is_err else C_DIM)


def process(obj):
    t = obj.get('type', '')

    if t == 'system' and obj.get('subtype') == 'init':
        head = (f"🚀 [初始化] 模型={obj.get('model') or ''} "
                f"版本={obj.get('qwen_code_version') or ''} "
                f"权限模式={obj.get('permission_mode') or ''} 工作目录=")
        # 字段多且长短不一, 整体按渲染宽度截断 (截掉的是尾部的工作目录)
        p(f"\n{C_INFO}{trunc(head + str(obj.get('cwd') or ''), TERM_WIDTH)}{C_RESET}")
        return

    if t == 'error':
        err = obj.get('error', '')
        if isinstance(err, dict):
            err = err.get('message', str(err))
        p(f"\n{C_ERR}🚨 [系统错误] {err}{C_RESET}")
        return

    if t == 'user':
        msg = obj.get('message')
        content = msg.get('content') if isinstance(msg, dict) else None
        if isinstance(content, str):
            content = [{'type': 'text', 'text': content}]
        if not isinstance(content, list):
            content = []
        text = ''.join(
            b.get('text', '') for b in content
            if isinstance(b, dict) and b.get('type') == 'text' and isinstance(b.get('text'), str)
        )
        if text.strip():
            first = plain(text.strip().split('\n', 1)[0])
            p(f"\n{C_INFO}{HDR_PROMPT}{trunc(first, W_PROMPT)}{C_RESET}")
        # qwen 0.23.x 的工具结果在 user 事件的 tool_result 内容块里,
        # 顶层没有 tool_use_result 字段
        for b in content:
            if isinstance(b, dict) and b.get('type') == 'tool_result':
                render_tool_result(b)
        return

    if t == 'assistant':
        msg = obj.get('message')
        content = msg.get('content') if isinstance(msg, dict) else None
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
                    # 已完整显示的字符数 (emit_text 只折行不截断), 供 result 事件去重
                    LAST_REPLY['shown'] = (TEXT_LIMIT if TEXT_LIMIT and len(text) > TEXT_LIMIT
                                           else len(text))
                if TEXT_LIMIT and len(text) > TEXT_LIMIT:
                    text = f"{text[:TEXT_LIMIT]} ... (已截断, 原文 {len(text)} 字符)"
                emit_text(text, color)
            elif bt == 'tool_use':
                name = block.get('name', '')
                inp = block.get('input') or {}
                icon, main, tail, key = describe_tool(name, inp)
                # 命令/路径里可能混入制表符或颜色序列, 先归一化再参与宽度计算与输出
                main, tail, key = plain(main), plain(tail), plain(key)
                # 前缀含缩进/图标/工具名, 主文本按剩余宽度截断, 后缀(如行号范围)不截断
                pfx = f"{INDENT}{icon} [{name}] "
                budget = line_budget(pfx + tail)
                p(f"{INDENT}{C_ACTION}{icon} [{name}]{C_RESET} {trunc(main, budget)}{tail}")
                TOOL_CALLS[block.get('id')] = {
                    'name': name,
                    'command': str(inp.get('command') or '') if isinstance(inp, dict) else '',
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
            names = []
            for d in denials:
                n = ''
                if isinstance(d, dict):
                    n = d.get('tool_name') or d.get('name') or d.get('tool_use_id') or ''
                if n and n not in names:
                    names.append(str(n))
            pfx = f"{INDENT}⚠️  权限被拒 {len(denials)} 次"
            detail = trunc(f": {'、'.join(names)}", line_budget(pfx)) if names else ''
            p(f"{C_ERR}{pfx}{detail}{C_RESET}")
        if is_err:
            err = obj.get('error')
            msg = err.get('message') if isinstance(err, dict) else err
            if msg:
                emit_lines(str(msg).splitlines(), C_ERR)
        else:
            res = obj.get('result')
            if res:
                text = str(res)
                # 与上方回复相同的内容只打一次: 已完整显示过就省略,
                # 回复曾被截断则接着截断处把剩余部分补完
                same = text.strip() == LAST_REPLY['text'].strip()
                rest = text[LAST_REPLY['shown']:] if same else text
                if same and not rest.strip():
                    p(f"{C_DIM}{RESULT_PFX}(与上方 💬 [回复] 相同, 已省略){C_RESET}")
                else:
                    if same:
                        p(f"{C_DIM}{RESULT_PFX}(上方 💬 [回复] 已截断, 以下为其余部分){C_RESET}")
                    # 最终结果是交付物, 折行输出而不是逐行截断
                    emit_text(rest, C_DIM, RESULT_PFX, CONTENT_LINES)
        TOOL_CALLS.clear()
        return

    if FMT_DEBUG:
        # 打印事件原文 (截断), 便于比对 qwen 升级后新增/变更的事件结构
        p(f"\n{C_DIM}❔ [未识别事件] type={t or '-'} subtype={obj.get('subtype') or '-'} "
          f"{trunc(json.dumps(obj, ensure_ascii=False), W_DEBUG)}{C_RESET}")


for raw in sys.stdin:
    raw = raw.strip()
    if not raw:
        continue
    try:
        obj = json.loads(raw)
    except json.JSONDecodeError:
        # --debug 经 2>&1 混入的非 JSON 行 (如 "Debug mode enabled")
        if FMT_DEBUG:
            p(f"\n{C_DIM}❔ [非 JSON 行] {trunc(raw, W_DEBUG)}{C_RESET}")
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
