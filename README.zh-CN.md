[English](README.md) | [中文](README.zh-CN.md)

# Agent Control Tower

通过 Named Pipe 在 Windows 上从一个终端编排多个 Claude Code 实例。一个 [Claude Code Skill](https://docs.anthropic.com/en/docs/claude-code)，将当前会话变为持续在线的指挥中枢，管理 agent 生命周期和任务。

## 工作原理

```
Claude Code（指挥者）
    │
    ├─ pipe-send.ps1 ──→ Named Pipe ──→ pipe-server.ps1（后台 C# 线程）
    │                                        │
    │                                        ▼
    │                                   WriteConsoleInput API
    │                                        │
    │                                        ▼
    │                                   目标终端 stdin
    │                                   （pwsh / claude code）
    │
    ├─ pipe-list.ps1     列出在线 agent
    └─ pipe-cleanup.ps1  优雅关闭 agent
```

每个 agent 在独立的 Windows Terminal tab 中运行，拥有独立的 Named Pipe。指挥者通过 `WriteConsoleInput` 注入键盘输入，兼容 pwsh 交互模式和 Claude Code TUI。

## 环境要求

- Windows 10/11
- [Windows Terminal](https://github.com/microsoft/terminal)
- PowerShell 7+（`pwsh.exe`）
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

## 安装

```bash
git clone https://github.com/Cedriccmh/agent-control-tower ~/.claude/skills/agent-control-tower
```

重启 Claude Code 即可使用。提到"开 agent"、"派任务"、"control tower"等关键词时自动触发。

## 使用方法

### 1. 检查现有 agent

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ~/.claude/skills/agent-control-tower/scripts/pipe-list.ps1
```

### 2. 启动 agent

```bash
wt.exe -w 0 new-tab -p "PowerShell" -d "C:\your-project" -- pwsh.exe -NoLogo -NoExit -Command \
  ". '$HOME/.claude/skills/agent-control-tower/scripts/pipe-server.ps1' -Id agent1" \
  && wt.exe -w 0 focus-tab -t 0
```

`pipe-server.ps1` 在 pipe 就绪后会自动启动 `claude --dangerously-skip-permissions`。

### 3. 发送任务

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ~/.claude/skills/agent-control-tower/scripts/pipe-send.ps1 -Id agent1 -Message "list all files"
```

### 4. 关闭

```powershell
# 关闭指定 agent
pwsh -NoProfile -ExecutionPolicy Bypass -File ~/.claude/skills/agent-control-tower/scripts/pipe-cleanup.ps1 -TargetId agent1

# 关闭所有 agent
pwsh -NoProfile -ExecutionPolicy Bypass -File ~/.claude/skills/agent-control-tower/scripts/pipe-cleanup.ps1
```

## 已验证功能

| 功能 | 状态 |
|------|------|
| Named Pipe 通信 | ✅ |
| WriteConsoleInput 键盘注入 | ✅ |
| 注入到 pwsh 交互模式 | ✅ |
| 注入到 Claude Code TUI | ✅ |
| 多 agent 独立管道 | ✅ |
| 零延迟焦点切回 | ✅ |
| 进程退出自动关闭 tab | ✅ |

## 已知限制

- **无法发送 CJK 字符** — ConPTY 层面的 `WriteConsoleInput` 限制。只能发送英文指令，agent 根据项目 `CLAUDE.md` 配置的语言回复。
- **仅限 Windows** — 依赖 Named Pipes、`WriteConsoleInput` 和 Windows Terminal。

## 许可证

[MIT](LICENSE)
