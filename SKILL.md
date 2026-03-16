---
name: agent-control-tower
description: 持续在线的跨终端 Claude Code 编排助手。通过 Named Pipe 启动、指挥、监控本地其他终端中的 Claude Code 实例，维护多 agent 生命周期。触发条件：用户提到"开 agent"、"启动 worker"、"派任务"、"指挥其他终端"、"pipe agent"、"多 agent"、"control tower"，或需要并行让多个 Claude Code 执行不同项目的任务。
---

# Agent Control Tower

通过 Named Pipe + WriteConsoleInput 持续编排本地多个 Claude Code 实例。当前会话作为指挥中枢，长期维护 agent 生命周期和任务交互。

## 脚本

skill 附带脚本，位于 `scripts/` 下：

| 脚本 | 用途 |
|------|------|
| `pipe-server.ps1` | 目标终端启动，建 pipe 监听并自动启动 Claude Code（需 C# WriteConsoleInput） |
| `pipe-send.py` | 向指定 agent 发命令（~3ms） |
| `pipe-list.py` | 列出在线 agent，离线自动清理（~120ms） |
| `pipe-cleanup.py` | 优雅关闭 agent：/exit + 杀进程树 |
| `hook-session-start.sh` | SessionStart hook → 写 ready 信号 |
| `hook-stop.sh` | Stop hook → 写 done 信号 |

定位脚本目录：用 Glob 搜索 `**/agent-control-tower/scripts/pipe-send.py` 获取路径，取其所在目录。所有命令中 `<SCRIPTS>` 均指此路径。

## 操作流程

### 1. 检查现有 agent

```bash
python "<SCRIPTS>/pipe-list.py"
```

在线 agent 可直接复用，无需重建。

### 2. 启动新 agent

```bash
wt.exe -w 0 new-tab -p "PowerShell" -d "<工作目录>" -- pwsh.exe -NoLogo -NoExit -Command ". '<SCRIPTS>/pipe-server.ps1' -Id <ID> -Name '<任务主题>'" && wt.exe -w 0 focus-tab -t 0
```

- `-Name` 设置 Claude Code 会话名（通过 `--name` 启动参数），便于用户在 tab 中识别任务。省略时默认用 ID
- `-Resume` 恢复上次会话，保留完整上下文继续工作（通过 `--resume` 启动参数）
- `&& focus-tab -t 0` 零延迟切回当前 tab
- 通过 ready 信号确认就绪后再发任务（见下方信号机制），或等待 **5-8 秒**
- **首次目录信任**：Claude Code 首次在某目录运行时会弹出信任确认。需发送 `1` 确认后 agent 才能就绪。已信任的目录不再提示

### 3. 等待就绪信号

```bash
# 轮询 ready 信号（SessionStart hook 写入）
while [ ! -f /c/tmp/claude_agents/signals/<ID>.ready ]; do sleep 1; done
echo "Agent <ID> ready"
```

信号文件由全局 hook（`~/.claude/hooks/hook-session-start.sh`）在 Claude Code 启动时自动写入。仅对设置了 `CLAUDE_AGENT_ID` 的 agent 会话生效，不影响普通会话。

### 4. 发送任务

```bash
python "<SCRIPTS>/pipe-send.py" <ID> "<英文指令>"
```

### 5. 监控任务完成

发送任务后，用**后台 Bash task**（`run_in_background: true`）监控 done 信号，不阻塞当前会话：

```bash
rm -f /c/tmp/claude_agents/signals/<ID>.done  # 清除上次信号
# ... 发送任务 ...
# 以下命令用 run_in_background 执行，完成时会收到通知
while [ ! -f /c/tmp/claude_agents/signals/<ID>.done ]; do sleep 2; done
echo "Agent <ID> task done"
```

收到通知后，review agent 的工作过程和结果，再向用户汇报：

```bash
# 查看 agent 完整工作记录（用了什么工具、读了哪些文件、有无异常）
python "<transcript-viewer的scripts路径>/view_transcript.py" -c "<agent工作目录>" -m 500
```

基于 transcript 向用户汇报后再发下一个任务。

### 6. 恢复会话（Resume）

当 agent 断开或需要续接上次工作时，用 `-Resume` 恢复会话：

```bash
wt.exe -w 0 new-tab -p "PowerShell" -d "<工作目录>" -- pwsh.exe -NoLogo -NoExit -Command ". '<SCRIPTS>/pipe-server.ps1' -Id <ID> -Name '<任务主题>' -Resume" && wt.exe -w 0 focus-tab -t 0
```

- 恢复上次会话的完整上下文，agent 可直接继续之前的任务
- 适用于 agent 意外退出、网络中断后重连等场景

### 7. 复用窗口切换任务

```bash
MSYS_NO_PATHCONV=1 python "<SCRIPTS>/pipe-send.py" <ID> "/exit"
# 等 5 秒让 Claude Code 退出
python "<SCRIPTS>/pipe-send.py" <ID> "cd <新目录>"
python "<SCRIPTS>/pipe-send.py" <ID> "claude --dangerously-skip-permissions"
# 等待 ready 信号，或等 5-8 秒（新目录可能触发信任确认，需发 "1"）
```

### 8. 关闭 agent

```bash
# 关闭全部（仅在用户要求时）
python "<SCRIPTS>/pipe-cleanup.py"
# 关闭指定
python "<SCRIPTS>/pipe-cleanup.py" <ID>
```

## 关键规则

- **英文指令**：pipe-send 只发英文（ConPTY 无法传 CJK 字符），agent 根据项目 CLAUDE.md 用中文回复
- **MSYS 路径转换**：Git Bash 传参时 `/exit` 会被转为路径。发送 `/` 开头的命令需加 `MSYS_NO_PATHCONV=1`
- **先查后操作**：启动前 `pipe-list` 检查，复用在线 agent
- **确认完成再发**：通过 done 信号确认任务完成后再发下一个
- **并行发送**：不同 agent 可并行，同一 agent 需串行
- **保持存活**：默认不关闭 agent，仅在用户要求或检测到离线时关闭
- **注册目录**：`C:\tmp\claude_agents\`，每个 agent 一个 `{id}.json`
- **信号目录**：`C:\tmp\claude_agents\signals\`，`{id}.ready` 和 `{id}.done` 由 hook 自动写入

## Hook 依赖

信号机制（`.ready` / `.done`）依赖两个全局 Claude Code hook。**首次使用前需配置**，详见 [references/setup.md](references/setup.md)。
