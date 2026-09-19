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

# 最终结果 (result.result) 是交付物: 开启后原样输出, 不加前缀/不折行/不截断,
# 便于直接落盘或管道给下游当 Markdown 用; 需要日志观感时保持关闭
RAW_RESULT = os.environ.get('FMT_RAW_RESULT', '') not in ('', '0')

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
# 工具结果每行的前缀: │ 与工具行/结果行里 "[" 同一列 (图标占 2 列 + 1 空格 = 第 4+3 列起)
RESULT_PFX  = '       │ '
HDR_PROMPT  = '👤 [用户提示词] '
HDR_ERROR   = '🚨 [系统错误] '
HDR_GOAL    = '🎯 [目标] '

# 子智能体 (agent/Task) 的消息带父 tool_use id, 属于另一个执行上下文:
# 整体多缩进一层, 标题行再加箭头, 免得主/子智能体的思考与回复在日志里混作一段
NEST_INDENT = '  '           # 子智能体事件每行的额外缩进
SUB_MARK    = '↳ '           # 子智能体事件标题行的箭头标记


def sub_hdr(nest):
    """子智能体事件标题行的前缀 (缩进+箭头); 主智能体事件返回空串"""
    return nest + SUB_MARK if nest else ''


def tool_ind(nest):
    """工具行与结果行标题的缩进: 子智能体的箭头列与其它标题对齐, 图标再进一层

    主智能体是 4 列 (INDENT); 子智能体是 2(缩进)+2(箭头)+2 = 6 列, 正好落在
    子智能体正文那一列, 与主智能体「工具行与正文同列」的关系保持一致
    """
    return sub_hdr(nest) + CONT_INDENT if nest else INDENT


# 工具/模型输出里可能混入 ANSI 颜色与制表符: 制表符按 1 列测量与实际显示 (跳到
# 制表位) 不符, 内嵌的 \x1b[0m 还会关掉本脚本给该行设的颜色, 因此统一先归一化
ANSI_RE = re.compile(r'\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b[@-Z\\-_]')
# Markdown 表格行 (| ... |): 折行会把它拆成两行, 复制出去不再是合法表格
TABLE_RE = re.compile(r'^\s*\|.*\|\s*$')


def plain(s, tab=4):
    """剥离 ANSI 颜色序列并展开制表符, 保证测量宽度与实际显示一致"""
    return ANSI_RE.sub('', s).expandtabs(tab)


# 0x2600-0x27BF 里 ✅ ❌ ⚡ 这类默认就按 emoji 渲染 (2 列), 但同区段的 ✓ ★ ➜ ♪
# 默认是文本呈现 (1 列, 只有带上 FE0F 才变 emoji), 按区段一刀切会把后者多算 1 列
TEXT_PRESENT_SYMBOLS = frozenset('✓✔✗✘★☆♪♫➜➔➤')


def char_width(c, next_c=''):
    """单个字符的显示宽度: 组合符与变体选择符 0 列, CJK/emoji 2 列, 其余 1 列

    next_c 是紧随其后的字符, 用来识别变体选择符 FE0F (文本呈现符号带上它才占 2 列)
    """
    code = ord(c)
    if code in (0xFE0E, 0xFE0F) or code == 0x200D or unicodedata.combining(c):
        return 0
    if unicodedata.east_asian_width(c) in 'FW':
        return 2
    # emoji 的呈现宽度不在 east_asian_width 里: 🛠 (U+1F6E0) 记作 N(1 列),
    # 终端实际按 2 列渲染, 这里按 Unicode 区段兜底
    if 0x1F000 <= code <= 0x1FAFF:
        return 2
    if 0x2600 <= code <= 0x27BF:
        return 1 if c in TEXT_PRESENT_SYMBOLS and next_c != '\uFE0F' else 2
    return 1


def disp_width(s):
    """整行显示宽度, 逐字符带上后一个字符以便识别变体选择符"""
    return sum(char_width(c, s[i + 1:i + 2]) for i, c in enumerate(s))


def trunc(s, width):
    """按显示宽度截断 (CJK/全角/emoji 占 2 列), 超宽时补 ..."""
    width = max(4, width)  # 给 "..." 留出空间, 极窄宽度下也不会越界
    if disp_width(s) <= width:
        return s
    out, w = [], 3
    for i, c in enumerate(s):
        cw = char_width(c, s[i + 1:i + 2])
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
        for i, c in enumerate(raw):
            cw = char_width(c, raw[i + 1:i + 2])
            # 用 while 而不是 if: 断行后剩余部分会落到更窄的续行预算上, 可能仍容不下 c,
            # 必须再断一次, 否则续行会超出 TERM_WIDTH (原实现只断一次, 会越界 1-2 列)
            while cur and cur_w + cw > budget:
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
    """整行给到 TERM_WIDTH 时, 前缀之后还能容纳的显示宽度

    minimum 是内容宽度的下限, 只在剩余空间确实够时才生效: 若前缀已占去大半行,
    宁可把内容压成 "...", 也不能让整行越过 TERM_WIDTH; 只有前缀自己就宽到
    放不下 "..." 时 (TERM_WIDTH 小于 前缀宽+4) 才退化为最小 4 列
    """
    room = TERM_WIDTH - disp_width(prefix)
    return room if room > minimum else max(4, room)


W_ERR   = line_budget(HDR_ERROR)
W_DEBUG = line_budget('❔ [未识别事件] ')


# result 事件子类型的中文说明 (未收录的原样输出)
SUBTYPE_CN = {
    'error_max_turns': '超出最大轮次',
    'error_during_execution': '执行出错',
}

# 工具名的中文标签 (未收录的原样输出): 日志主要给中文用户看, 工具名也统一成中文
TOOL_CN = {
    'read_file': '读取文件', 'write_file': '写入文件',
    'edit': '编辑文件', 'notebook_edit': '编辑笔记',
    'run_shell_command': '执行命令', 'monitor': '监控命令',
    'grep_search': '搜索内容', 'glob': '查找文件', 'list_directory': '列出目录',
    'web_fetch': '抓取网页', 'read_mcp_resource': '读取资源',
    'agent': '子智能体', 'skill': '调用技能',
    'record_artifact': '记录产物', 'send_message': '发送消息',
    'report_findings': '上报发现', 'zoom_image': '放大图片',
    'list_agents': '列出智能体', 'task_stop': '停止任务',
    'cron_create': '创建定时任务', 'cron_list': '查看定时任务',
    'cron_delete': '删除定时任务', 'loop_wakeup': '循环唤醒',
    'get_goal': '读取目标', 'update_goal': '更新目标',
    'enter_worktree': '进入工作树', 'exit_worktree': '退出工作树',
    'todo_write': '记录待办',
}

# Claude Code 风格的工具名归一成 qwen 侧的名字, 让两种事件源共用同一套渲染与标签
TOOL_ALIAS = {
    'Read': 'read_file', 'Write': 'write_file', 'Edit': 'edit', 'MultiEdit': 'edit',
    'NotebookRead': 'read_file', 'NotebookEdit': 'notebook_edit',
    'Bash': 'run_shell_command', 'Grep': 'grep_search', 'Glob': 'glob',
    'LS': 'list_directory', 'WebFetch': 'web_fetch', 'Task': 'agent',
    'TodoWrite': 'todo_write',
}

# 未收录工具的输入压成 k=v 摘要时, 常见参数名一并译成中文 (未收录的原样输出)
PARAM_CN = {
    'file_path': '文件', 'path': '路径', 'directory': '目录', 'url': '网址',
    'pattern': '模式', 'query': '关键词', 'offset': '起始行', 'limit': '行数',
    'name': '名称', 'id': '编号', 'status': '状态', 'reason': '原因',
    'level': '级别', 'findings': '清单', 'action': '动作', 'view': '视图',
    'cron': '周期', 'recurring': '重复', 'prompt': '提示词',
    'delaySeconds': '延迟秒', 'task_id': '任务', 'timeout': '超时',
    'content': '内容', 'description': '说明', 'message': '消息',
    'summary': '摘要', 'subagent_type': '子智能体类型',
    'evidenceRefs': '证据引用', 'blockerKind': '阻塞类型',
    'workspacePath': '产物路径', 'cell_id': '单元格',
    'x1': '左边界', 'y1': '上边界', 'x2': '右边界', 'y2': '下边界',
}

# tool_use_id -> 该次调用的工具名/命令/是否已完整显示, 供 tool_result 标注与去重
TOOL_CALLS = {}
# 最后一条回复的全文, 以及其中已被完整显示的字符数 (供 result 事件去重)
LAST_REPLY = {'text': '', 'shown': 0}
# 上一次的 goal_state 摘要: 状态每次变化都会上报一次, 去重后只打变化的那一次
LAST_GOAL = {'state': None}


def p(s, end='\n'):
    print(s, end=end, flush=True)


def emit_lines(lines, color, nest=''):
    """输出工具结果: 保留缩进, 按显示宽度截断, 行数超限折叠"""
    limit = CONTENT_LINES or len(lines)
    pfx = nest + RESULT_PFX
    width = line_budget(pfx)
    for ln in lines[:limit]:
        # 空行也要去掉前缀尾部的空格, 避免日志里出现行尾空白
        p(f"{color}{(pfx + trunc(plain(ln).rstrip(), width)).rstrip()}{C_RESET}")
    if len(lines) > limit:
        p(f"{color}{pfx}... (还有 {len(lines) - limit} 行){C_RESET}")


def emit_text(text, color, prefix=INDENT, limit=0, nest=''):
    """输出思考/回复/最终结果正文: 折叠连续空行, 长行折行 (不丢字符)

    Markdown 表格行不折行: 交付物里最常见的就是表格, 折行会让它复制出去后不再是
    合法表格; 超宽交给终端软换行, 阅读观感与折行一致而复制结果完好
    """
    lines = collapse_blanks(text)
    limit = limit or len(lines)
    for ln in lines[:limit]:
        if TABLE_RE.match(ln):
            p(f"{color}{nest}{prefix}{ln}".rstrip() + C_RESET)
            continue
        for seg in wrap(ln, line_budget(nest + prefix)):
            p(f"{color}{nest}{prefix}{seg}".rstrip() + C_RESET)
    if len(lines) > limit:
        p(f"{color}{nest}{prefix}... (还有 {len(lines) - limit} 行){C_RESET}")


def brief(value, width=60):
    """兜底摘要里的值: 容器只报元素/键个数, 长值截断并压成单行, 避免 Python repr"""
    if isinstance(value, dict):
        return f"{{{len(value)} 键}}"
    if isinstance(value, (list, tuple)):
        return f"[{len(value)} 项]"
    return trunc(' '.join(str(value).split()), width)


def goal_brief(goal):
    """目标对象的单行摘要: 优先取描述字段, 结构不认识时退回单行 JSON"""
    if isinstance(goal, dict):
        for k in ('objective', 'prompt', 'title', 'name', 'summary'):
            v = goal.get(k)
            if isinstance(v, str) and v.strip():
                return ' '.join(v.split())
        return json.dumps(goal, ensure_ascii=False)
    return ' '.join(str(goal).split())


def compact(inp):
    """把未收录工具的输入压成 k=v 一行摘要 (常见参数名一并译成中文)"""
    return ' '.join(
        f"{PARAM_CN.get(k, k)}={brief(v)}" for k, v in inp.items()
        if v not in (None, '', [], {})
    )


def describe_tool(name, inp):
    """把 tool_use 的输入压成一行摘要

    返回 (图标, 主文本, 不参与截断的后缀, 判断「已完整显示」的关键文本):
    主文本按剩余宽度截断, 后缀 (如 read_file 的行号范围) 永不截断;
    关键文本用于判断命令行是否完整可见 (命令后的描述被截掉不影响该判断);
    Claude Code 风格的别名 (Read/Bash/Edit...) 先归一成 qwen 侧的名字再分发
    """
    if not isinstance(inp, dict):
        # 输入形态异常时不能因属性缺失丢掉整条事件
        text = brief(inp)
        return '🛠️', text, '', text
    name = TOOL_ALIAS.get(name, name)
    if name in ('run_shell_command', 'monitor'):
        cmd = str(inp.get('command') or '').replace('\r\n', '; ').replace('\n', '; ')
        # 描述只是附加说明, 压成单行以免工具行被换行冲散
        desc = ' '.join(str(inp.get('description') or '').split())
        return '⚡', f"$ {cmd}" + (f"   # {desc}" if desc else ''), '', f"$ {cmd}"
    if name in ('read_file', 'write_file', 'edit', 'notebook_edit'):
        icon = {'read_file': '📄', 'write_file': '📝',
                'edit': '✏️', 'notebook_edit': '📓'}[name]
        tail = ''
        if name == 'read_file' and inp.get('offset') is not None:
            tail = f" 第{inp.get('offset')}行起"
            if inp.get('limit') is not None:
                tail += f", 共{inp.get('limit')}行"
        elif name == 'edit':
            old = str(inp.get('old_string') or '')
            new = str(inp.get('new_string') or '')
            # 编辑规模(增删行数)比 old_string 原文更有信息量, 空串记 0 行
            n_del = old.count('\n') + 1 if old else 0
            n_add = new.count('\n') + 1 if new else 0
            if n_del or n_add:
                tail = f"  -{n_del}行/+{n_add}行"
        fp = str(inp.get('file_path') or inp.get('notebook_path') or '')
        if name == 'notebook_edit' and inp.get('cell_id'):
            fp += f" 单元格={inp.get('cell_id')}"
        if not fp:
            # 路径缺失时退回 k=v 摘要, 免得打出一条只有图标和工具名的空行
            fp = compact(inp)
        return icon, fp, tail, fp
    if name in ('grep_search', 'glob'):
        pat = str(inp.get('pattern') or inp.get('query') or '')
        where = inp.get('path') or inp.get('directory')
        main = pat + (f"   在 {where}" if where else '')
        return '🔍', main, '', main
    if name == 'web_fetch':
        url = str(inp.get('url') or '')
        # 同一 URL 可能配不同 prompt (缓存命中的重复抓取), 带上 prompt 才区分得开
        prompt = ' '.join(str(inp.get('prompt') or '').split())
        return '🌐', url + (f"   # {prompt}" if prompt else ''), '', url
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


def block_text(block):
    """把 tool_result 的一个内容块归一成文本

    text 块取原文; 图片块只报格式与大小 (base64 原文没有阅读价值, 还会顶掉整行);
    其余结构压成单行 JSON, 避免漏出带单引号的 Python repr
    """
    if isinstance(block, str):
        return block
    if not isinstance(block, dict):
        return brief(block)
    text = block.get('text')
    if isinstance(text, str):
        return text
    if block.get('type') == 'image':
        src = block.get('source') if isinstance(block.get('source'), dict) else {}
        data = src.get('data') if isinstance(src.get('data'), str) else ''
        # base64 长度与原始字节数约为 4:3, 只做量级估计
        kind = str(src.get('media_type') or '图片').rpartition('/')[2]
        return f"[图片 {kind}{f', 约 {len(data) * 3 // 4} 字节' if data else ''}]"
    return json.dumps(block, ensure_ascii=False)


def content_text(content):
    """把 tool_result 的 content 归一成文本

    字符串原样; 内容块列表逐块取文本; 字典按 JSON 缩进展示 (结构化结果多一层
    缩进比压成一行更好读), 其余类型退化为 str
    """
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return '\n'.join(block_text(b) for b in content)
    if isinstance(content, dict):
        return json.dumps(content, ensure_ascii=False, indent=2)
    return str(content)


def render_tool_result(block, nest=''):
    call = TOOL_CALLS.get(block.get('tool_use_id')) or {}
    name = call.get('name')
    is_err = bool(block.get('is_error'))
    icon, color, title = ('❌', C_ERR, '[错误]') if is_err else ('✅', C_RESULT, '[结果]')
    label = TOOL_CN.get(name, name) if name else ''
    p(f"{tool_ind(nest)}{color}{icon} {title}{f' {label}' if label else ''}{C_RESET}")
    content = block.get('content')
    if content is None:
        return
    lines = content_text(content).rstrip().splitlines()
    if not is_err and name == 'run_shell_command':
        lines = strip_shell_echo(lines, call)
    emit_lines(lines, C_ERR if is_err else C_DIM, nest)


def first_of(obj, *keys):
    """按顺序取第一个非空值: qwen 与 Claude Code 的同义字段名不同, 两套都认"""
    for k in keys:
        v = obj.get(k)
        if v not in (None, ''):
            return v
    return ''


def render_mcp_servers(servers):
    """MCP 服务器清单: 连不上是常见排障点, 只在非空时补一行"""
    if not isinstance(servers, list) or not servers:
        return
    items = []
    for s in servers:
        if isinstance(s, dict):
            name = str(s.get('name') or '')
            status = str(s.get('status') or '')
            items.append(f"{name}({status})" if status else name)
        elif s:
            items.append(str(s))
    items = [i for i in items if i]
    if items:
        pfx = f"{INDENT}🔌 MCP 服务器 {len(items)} 个: "
        p(f"{C_INFO}{pfx}{trunc('、'.join(items), line_budget(pfx))}{C_RESET}")


def render_goal_state(gs):
    """目标状态: 只在变化且值得一看时打一行

    无目标且空闲没有信息量 (多数任务不使用目标), 此时只记录状态用于去重;
    之后每次真实变化 (含回到空闲) 都会打一行
    """
    activity = str(gs.get('activity') or '')
    goal = gs.get('goal')
    state = f"{activity}|{goal_brief(goal) if goal not in (None, '', {}, []) else ''}"
    if state == LAST_GOAL['state']:
        return
    LAST_GOAL['state'] = state
    if not goal and activity in ('', 'idle'):
        return
    line = f"{HDR_GOAL}活动={activity or '-'}"
    if goal not in (None, '', {}, []):
        line += f" 目标={trunc(goal_brief(goal), 80)}"
    p(f"\n{C_INFO}{trunc(line, TERM_WIDTH)}{C_RESET}")


def process(obj):
    t = obj.get('type', '')
    # 子智能体 (agent/Task) 的消息带父 tool_use id: 渲染时整体缩进一层并加箭头
    nest = NEST_INDENT if obj.get('parent_tool_use_id') else ''

    if t == 'system' and obj.get('subtype') == 'init':
        sess = f" 会话={str(obj.get('session_id') or '')[:8]}" if obj.get('session_id') else ''
        head = (f"🚀 [初始化] 模型={obj.get('model') or ''} "
                f"版本={first_of(obj, 'qwen_code_version', 'claude_code_version', 'version')} "
                f"权限模式={first_of(obj, 'permission_mode', 'permissionMode')}{sess} "
                f"工作目录=")
        # 字段多且长短不一, 整体按渲染宽度截断 (截掉的是尾部的工作目录)
        p(f"\n{C_INFO}{trunc(head + str(obj.get('cwd') or ''), TERM_WIDTH)}{C_RESET}")
        render_mcp_servers(obj.get('mcp_servers'))
        return

    if t == 'stream_event':
        ev = obj.get('event')
        gs = ev.get('goal_state') if isinstance(ev, dict) else None
        # 其余 stream_event (content_block_delta 等) 是 assistant 事件的增量,
        # 内容已由 assistant 事件完整覆盖, 不能重复渲染
        if isinstance(gs, dict):
            render_goal_state(gs)
            return

    if t == 'error':
        err = obj.get('error', '')
        if isinstance(err, dict):
            err = err.get('message', str(err))
        lines = str(err).splitlines() or ['']
        # 首行与头部同行, 其余行按结果行渲染: 直接原样打印会让多行或超长的
        # 错误信息冲出版式 (续行丢失前缀, 单行可达几百列)
        p(f"\n{C_ERR}{HDR_ERROR}{trunc(plain(lines[0]).rstrip(), W_ERR)}{C_RESET}")
        if len(lines) > 1:
            emit_lines(lines[1:], C_ERR)
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
            lines = text.strip().splitlines()
            hdr = sub_hdr(nest) + HDR_PROMPT
            # 只打首行会把多行提示词的其余内容悄悄丢掉, 因此补上总行数
            more = f" (共 {len(lines)} 行)" if len(lines) > 1 else ''
            budget = line_budget(hdr)
            p(f"\n{C_INFO}{hdr}"
              f"{trunc(plain(lines[0]), max(4, budget - disp_width(more)))}{more}{C_RESET}")
        # qwen 0.23.x 的工具结果在 user 事件的 tool_result 内容块里,
        # 顶层没有 tool_use_result 字段
        for b in content:
            if isinstance(b, dict) and b.get('type') == 'tool_result':
                render_tool_result(b, nest)
        return

    if t == 'assistant':
        msg = obj.get('message')
        content = msg.get('content') if isinstance(msg, dict) else None
        if not isinstance(content, list):
            return
        # 当前小节: 'thought' / 'reply' / None (工具行不切换小节)
        section = None
        # 工具行与正文同缩进, 首条工具行前空一行才不会看成正文的下一句
        first_tool = True
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
                        p(f"\n{sub_hdr(nest)}{C_THOUGHT}🧠 [思考]{C_RESET}")
                        color = C_THOUGHT
                    else:
                        p(f"\n{sub_hdr(nest)}{C_REPLY}💬 [回复]{C_RESET}")
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
                emit_text(text, color, INDENT, 0, nest)
            elif bt == 'tool_use':
                name = TOOL_ALIAS.get(block.get('name') or '', block.get('name') or '')
                inp = block.get('input') or {}
                if first_tool:
                    p('')
                    first_tool = False
                icon, main, tail, key = describe_tool(name, inp)
                # 命令/路径里可能混入制表符或颜色序列, 先归一化再参与宽度计算与输出
                main, tail, key = plain(main), plain(tail), plain(key)
                # 前缀含缩进/图标/工具名, 主文本按剩余宽度截断, 后缀(如行号范围)不截断;
                # 但后缀自己也可能把整行占满, 这时先压缩后缀, 保证整行不超 TERM_WIDTH
                label = TOOL_CN.get(name, name)
                pfx = f"{tool_ind(nest)}{icon} [{label}] "
                room = TERM_WIDTH - disp_width(pfx)
                if disp_width(tail) > max(0, room - 8):
                    tail = trunc(tail, max(4, room - 8))
                budget = line_budget(pfx + tail)
                p(f"{tool_ind(nest)}{C_ACTION}{icon} [{label}]{C_RESET} "
                  f"{trunc(main, budget)}{tail}")
                TOOL_CALLS[block.get('id')] = {
                    'name': name,
                    'command': str(inp.get('command') or '') if isinstance(inp, dict) else '',
                    'shown_full': disp_width(key) <= budget,
                }
        stop = msg.get('stop_reason')
        if stop and stop not in ('end_turn', 'tool_use', 'stop_sequence'):
            # 异常结束(如 max_tokens)意味着上方内容其实被截断了, 必须显式提示
            p(f"\n{tool_ind(nest)}{C_ERR}⚠️  回复因 {stop} 中断, 内容可能不完整{C_RESET}")
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
        head = f"{icon} [结束] " + ' '.join(info)
        p(f"\n{c}{trunc(head, TERM_WIDTH)}{C_RESET}")
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
            if res and RAW_RESULT:
                # 交付物按原文送出: 不折行不加前缀, 便于落盘或管道给下游
                p(str(res))
            elif res:
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
    if not isinstance(obj, dict):
        # stream-json 事件都是对象; 标量/数组说明这行不是事件, 不能当事件渲染
        if FMT_DEBUG:
            p(f"\n{C_DIM}❔ [非对象 JSON] {trunc(raw, W_DEBUG)}{C_RESET}")
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
