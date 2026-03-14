# Agent Control Tower

Orchestrate multiple Claude Code instances from a single terminal via Named Pipes on Windows.

一个 Claude Code Skill，让你在一个终端中持续指挥多个 Claude Code 实例并行执行任务。

## How It Works

```
Claude Code (commander)
    │
    ├─ pipe-send.ps1 ──→ Named Pipe ──→ pipe-server.ps1 (background C# thread)
    │                                        │
    │                                        ▼
    │                                   WriteConsoleInput API
    │                                        │
    │                                        ▼
    │                                   Target terminal stdin
    │                                   (pwsh / claude code)
    │
    ├─ pipe-list.ps1     List online agents
    └─ pipe-cleanup.ps1  Gracefully shutdown agents
```

Each agent runs in its own Windows Terminal tab with an independent Named Pipe. The commander sends keystrokes via `WriteConsoleInput`, which works reliably with both pwsh interactive mode and Claude Code TUI.

每个 agent 在独立的 Windows Terminal tab 中运行，通过 Named Pipe 接收指令。指挥者通过 `WriteConsoleInput` 注入键盘输入，兼容 pwsh 交互模式和 Claude Code TUI。

## Requirements

- Windows 10/11
- [Windows Terminal](https://github.com/microsoft/terminal)
- PowerShell 7+ (`pwsh.exe`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

## Install

```bash
git clone https://github.com/Cedriccmh/agent-control-tower ~/.claude/skills/agent-control-tower
```

Restart Claude Code. The skill auto-triggers when you mention "agent", "worker", "dispatch", or "control tower".

重启 Claude Code 即可使用。提到"开 agent"、"派任务"、"control tower"等关键词时自动触发。

## Usage

### 1. Check existing agents / 检查现有 agent

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ~/.claude/skills/agent-control-tower/scripts/pipe-list.ps1
```

### 2. Launch an agent / 启动 agent

```bash
wt.exe -w 0 new-tab -p "PowerShell" -d "C:\your-project" -- pwsh.exe -NoLogo -NoExit -Command \
  ". '$HOME/.claude/skills/agent-control-tower/scripts/pipe-server.ps1' -Id agent1" \
  && wt.exe -w 0 focus-tab -t 0
```

`pipe-server.ps1` automatically starts `claude --dangerously-skip-permissions` after the pipe is ready.

### 3. Send a task / 发送任务

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ~/.claude/skills/agent-control-tower/scripts/pipe-send.ps1 -Id agent1 -Message "list all files"
```

### 4. Shutdown / 关闭

```powershell
# Shutdown a specific agent
pwsh -NoProfile -ExecutionPolicy Bypass -File ~/.claude/skills/agent-control-tower/scripts/pipe-cleanup.ps1 -TargetId agent1

# Shutdown all agents
pwsh -NoProfile -ExecutionPolicy Bypass -File ~/.claude/skills/agent-control-tower/scripts/pipe-cleanup.ps1
```

## Verified Features

| Feature | Status |
|---------|--------|
| Named Pipe communication | ✅ |
| WriteConsoleInput keystroke injection | ✅ |
| Inject into pwsh interactive mode | ✅ |
| Inject into Claude Code TUI | ✅ |
| Multiple independent agents | ✅ |
| Zero-delay focus switch back | ✅ |
| Auto close tab on process exit | ✅ |

## Known Limitations

- **CJK characters cannot be sent** via pipe — ConPTY limitation with `WriteConsoleInput`. Send commands in English only; agents respond in the language configured by their project's `CLAUDE.md`.
- **Windows only** — relies on Named Pipes, `WriteConsoleInput`, and Windows Terminal.

## License

[MIT](LICENSE)
