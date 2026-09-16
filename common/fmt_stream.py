import sys
import json
import shutil

TEXT_LIMIT    = 3000  # 稍微放宽了总字数
CONTENT_LINES = 30    # 增加预览行数至 30 行

# Colors for terminal output
C_THOUGHT = '\033[38;5;245m'
C_ACTION  = '\033[1;36m'
C_RESULT  = '\033[0;32m'
C_INFO    = '\033[1;34m'
C_WARN    = '\033[38;5;214m'
C_ERR     = '\033[0;31m'
C_RESET   = '\033[0m'
C_DIM     = '\033[2m'

def p(s, end='\n'):
    print(s, end=end, flush=True)

def process(obj):
    # 将默认回退列数增加到 200
    term_width = shutil.get_terminal_size((200, 24)).columns

    # 动态计算不同场景的可用宽度
    # W_PROMPT: 👤 [User Prompt] (约 18 字符)
    W_PROMPT = max(80, term_width - 25)
    # W_CMD: ⚡ [Bash] $ (约 15 字符)
    W_CMD    = max(80, term_width - 20)
    # W_LINE: │ (约 10 字符)
    W_LINE   = max(80, term_width - 15)

    t = obj.get('type', '')

    if t == 'system' and obj.get('subtype') == 'init':
        p(f"\n{C_INFO}🚀 [Init] model={obj.get('model','')} cwd={obj.get('cwd','')}{C_RESET}")
        return

    if t == 'error':
        err_msg = obj.get('error', '')
        if isinstance(err_msg, dict):
            err_msg = err_msg.get('message', str(err_msg))
        p(f"\n{C_ERR}🚨 [System Error] {err_msg}{C_RESET}")
        return

    if t == 'user':
        content = obj.get('message', {}).get('content', [])
        text = "".join([str(b.get('text', '')) for b in content if isinstance(b, dict) and b.get('type') == 'text'])
        if text:
            lines = text.strip().split("\n")
            if lines:
                short_str = str(lines[0])[:W_PROMPT]
                suffix = "..." if len(str(lines[0])) > W_PROMPT else ""
                p(f"\n{C_INFO}👤 [User Prompt] {short_str}{suffix}{C_RESET}")
        return

    if t == 'assistant':
        content = obj.get('message', {}).get('content', [])
        has_thought = False
        for block in content:
            bt = block.get('type', '')
            if bt == 'text':
                text = block.get('text', '').strip()
                if not text: continue
                if len(text) > TEXT_LIMIT: text = text[:TEXT_LIMIT] + ' ... (truncated)'
                if not has_thought:
                    p(f"\n{C_THOUGHT}🧠 [Thought]{C_RESET}")
                    has_thought = True
                for ln in text.splitlines():
                    if ln.strip(): p(f"{C_THOUGHT}    {ln}{C_RESET}")
            elif bt == 'tool_use':
                name = block.get('name', '')
                inp  = block.get('input', {})
                if name == 'Bash':
                    cmd = inp.get('command', '').replace('\n', '; ')[:W_CMD]
                    p(f"    {C_ACTION}⚡ [{name}]{C_RESET} $ {cmd}")
                elif name == 'Read':
                    fp = inp.get('file_path', '')
                    rng = f" L{inp.get('offset', '')}+{inp.get('limit', '')}" if inp.get('offset') else ""
                    p(f"    {C_ACTION}📄 [{name}]{C_RESET} {fp}{rng}")
                else:
                    p(f"    {C_ACTION}🛠️  [{name}]{C_RESET} {str(inp)[:W_CMD]}")
        return

    tr = obj.get('tool_use_result') or (obj if t == 'tool_result' else None)
    if tr is not None:
        has_content = False
        parts = []
        is_err = False
        if isinstance(tr, dict):
            stdout = tr.get('stdout', '')
            stderr = tr.get('stderr', '')
            content = tr.get('content', '')
            if str(tr.get('exitCode', '0')) != '0' or tr.get('is_error'):
                is_err = True
            for k in ('numLines', 'totalLines', 'numFiles', 'exitCode'):
                if k in tr: parts.append(f"{k}={tr[k]}")
            if stdout or stderr or content: has_content = True
        elif (isinstance(tr, list) and tr) or str(tr).strip():
            has_content = True

        icon, color, title = ('❌', C_ERR, '[Error]') if is_err else ('✅', C_RESULT, '[Result]')
        p(f"{color}    {icon} {title}{C_RESET}")

        if isinstance(tr, dict):
            for label, data, c in [('stdout', stdout, C_DIM), ('stderr', stderr, C_ERR if is_err else C_WARN)]:
                if data:
                    lines = data.rstrip().splitlines()
                    for ln in lines[:CONTENT_LINES]:
                        p(f"{c}      │ {ln.strip()[:W_LINE]}{C_RESET}")
                    if len(lines) > CONTENT_LINES:
                        p(f"{c}      │ ... ({len(lines) - CONTENT_LINES} more lines){C_RESET}")

            if content and not stdout:
                lines = content.splitlines() if isinstance(content, str) else [str(i) for i in (content if isinstance(content, list) else [content])]
                for ln in lines[:CONTENT_LINES]:
                    p(f"{C_DIM}      │ {ln.strip()[:W_LINE]}{C_RESET}")
            if parts:
                p(f"{C_DIM}      ╰─ {', '.join(parts)}{C_RESET}")
        else:
            text = str(tr).strip()
            if text:
                for ln in text.splitlines()[:CONTENT_LINES]:
                    p(f"{C_DIM}      │ {ln.strip()[:W_LINE]}{C_RESET}")
        return

    if t == 'result':
        p(f"\n{C_INFO}🏁 [结束 DONE] turns={obj.get('num_turns', 0)} cost=${obj.get('cost_usd', 0):.4f}{C_RESET}")

for raw in sys.stdin:
    raw = raw.strip()
    if not raw: continue
    try:
        obj = json.loads(raw)
        process(obj)
    except (ValueError, Exception):
        continue