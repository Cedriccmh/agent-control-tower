[English](README.md) | [中文](README.zh-CN.md)

# Agent Control Tower

Orchestrate multiple Claude Code instances from a single terminal via Named Pipes on Windows. A [Claude Code Skill](https://docs.anthropic.com/en/docs/claude-code) that turns your current session into a persistent command center for managing agent lifecycles and tasks.

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

## Usage

### 1. Check existing agents

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ~/.claude/skills/agent-control-tower/scripts/pipe-list.ps1
```

### 2. Launch an agent

```bash
wt.exe -w 0 new-tab -p "PowerShell" -d "C:\your-project" -- pwsh.exe -NoLogo -NoExit -Command \
  ". '$HOME/.claude/skills/agent-control-tower/scripts/pipe-server.ps1' -Id agent1" \
  && wt.exe -w 0 focus-tab -t 0
```

`pipe-server.ps1` automatically starts `claude --dangerously-skip-permissions` after the pipe is ready.

### 3. Send a task

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ~/.claude/skills/agent-control-tower/scripts/pipe-send.ps1 -Id agent1 -Message "list all files"
```

### 4. Shutdown

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
