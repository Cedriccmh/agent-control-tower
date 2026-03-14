---
name: agent-control-tower
description: 持续在线的跨终端 Claude Code 编排助手。通过 Named Pipe 启动、指挥、监控本地其他终端中的 Claude Code 实例，维护多 agent 生命周期。触发条件：用户提到"开 agent"、"启动 worker"、"派任务"、"指挥其他终端"、"pipe agent"、"多 agent"、"control tower"，或需要并行让多个 Claude Code 执行不同项目的任务。
---

# Agent Control Tower

通过 Named Pipe + WriteConsoleInput 持续编排本地多个 Claude Code 实例。当前会话作为指挥中枢，长期维护 agent 生命周期和任务交互。

## 脚本

skill 附带 4 个 PowerShell 脚本，位于 `scripts/` 下：

| 脚本 | 用途 |
|------|------|
| `pipe-server.ps1` | 目标终端启动，建 pipe 监听并自动启动 Claude Code |
| `pipe-send.ps1` | 向指定 agent 发命令 |
| `pipe-list.ps1` | 列出在线 agent（离线自动清理） |
| `pipe-cleanup.ps1` | 优雅关闭 agent（/exit + 杀进程树） |

定位脚本目录：获取本 SKILL.md 所在目录的 `scripts/` 子目录路径。所有命令中 `<SCRIPTS>` 均指此路径。

## 操作流程

### 1. 检查现有 agent

```bash
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "<SCRIPTS>/pipe-list.ps1"
```

在线 agent 可直接复用，无需重建。

### 2. 启动新 agent

```bash
wt.exe -w 0 new-tab -p "PowerShell" -d "<工作目录>" -- pwsh.exe -NoLogo -NoExit -Command ". '<SCRIPTS>/pipe-server.ps1' -Id <ID>" && wt.exe -w 0 focus-tab -t 0
```

- pipe-server 自动启动 `claude --dangerously-skip-permissions`
- `&& focus-tab -t 0` 零延迟切回当前 tab
- 等待 ~15 秒让 Claude Code 加载完成

### 3. 发送任务

```bash
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "<SCRIPTS>/pipe-send.ps1" -Id <ID> -Message "<英文指令>"
```

### 4. 查看执行结果

```bash
python "$USERPROFILE/.claude/skills/transcript-viewer/scripts/view_transcript.py" -c "<agent工作目录>" -m 500
```

确认任务完成后再发下一个。

### 5. 复用窗口切换任务

```bash
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "<SCRIPTS>/pipe-send.ps1" -Id <ID> -Message "/exit"
# 等几秒
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "<SCRIPTS>/pipe-send.ps1" -Id <ID> -Message "cd <新目录>"
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "<SCRIPTS>/pipe-send.ps1" -Id <ID> -Message "claude --dangerously-skip-permissions"
```

### 6. 关闭 agent

```bash
# 关闭全部（仅在用户要求时）
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "<SCRIPTS>/pipe-cleanup.ps1"
# 关闭指定
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "<SCRIPTS>/pipe-cleanup.ps1" -TargetId <ID>
```

## 关键规则

- **英文指令**：pipe-send 只发英文（ConPTY 无法传 CJK 字符），agent 根据项目 CLAUDE.md 用中文回复
- **先查后操作**：启动前 `pipe-list` 检查，复用在线 agent
- **确认完成再发**：通过 transcript 确认上一个任务完成后再发下一个
- **并行发送**：不同 agent 可并行，同一 agent 需串行
- **保持存活**：默认不关闭 agent，仅在用户要求或检测到离线时关闭
- **注册目录**：`C:\tmp\claude_agents\`，每个 agent 一个 `{id}.json`
