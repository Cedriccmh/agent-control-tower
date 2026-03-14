# Hook 配置指南

一次性配置。配置完成后日常使用无需再查阅本文件。

## 前提

- Windows 10/11 + Windows Terminal + PowerShell 7+
- Python 3.8+
- Claude Code CLI (`claude` in PATH)

## 1. 创建 hook 符号链接

将 `scripts/` 下的 hook 脚本链接到 `~/.claude/hooks/`。

**符号链接**（推荐，需开发者模式或管理员权限）：

```bash
mkdir -p "$USERPROFILE/.claude/hooks"
MSYS=winsymlinks:nativestrict ln -s "<SCRIPTS>/hook-session-start.sh" "$USERPROFILE/.claude/hooks/hook-session-start.sh"
MSYS=winsymlinks:nativestrict ln -s "<SCRIPTS>/hook-stop.sh" "$USERPROFILE/.claude/hooks/hook-stop.sh"
```

**硬链接**（备选，无需管理员但要求同卷，git 更新 submodule 可能断链）：

```bash
ln "<SCRIPTS>/hook-session-start.sh" "$USERPROFILE/.claude/hooks/hook-session-start.sh"
ln "<SCRIPTS>/hook-stop.sh" "$USERPROFILE/.claude/hooks/hook-stop.sh"
```

## 2. 在 `~/.claude/settings.json` 中注册 hook

在 JSON 顶层添加 `hooks` 字段。**命令必须用绝对路径**，`$USERPROFILE` 等环境变量不被展开。

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash C:/Users/<你的用户名>/.claude/hooks/hook-session-start.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash C:/Users/<你的用户名>/.claude/hooks/hook-stop.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

## Hook 原理

| Hook 脚本 | 事件 | 作用 |
|-----------|------|------|
| `hook-session-start.sh` | SessionStart | 写 `{id}.ready` 信号 |
| `hook-stop.sh` | Stop | 写 `{id}.done` 信号 |

- hook 通过 `CLAUDE_AGENT_ID` 环境变量识别 agent 会话
- 非 agent 会话自动跳过（`exit 0`，零开销）
- `pipe-server.ps1` 在启动 `claude` 前设置 `$env:CLAUDE_AGENT_ID = $Id`
- 信号文件位于 `C:\tmp\claude_agents\signals\`

## 验证

```bash
# 手动测试 hook
CLAUDE_AGENT_ID=test bash "$USERPROFILE/.claude/hooks/hook-session-start.sh"
cat /c/tmp/claude_agents/signals/test.ready
# 应输出 JSON: {"agent_id":"test","event":"ready","time":"..."}

# 清理
rm -f /c/tmp/claude_agents/signals/test.ready
```
