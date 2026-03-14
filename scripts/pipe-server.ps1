# pipe-server.ps1 - Named Pipe 后台监听 + 控制台输入注入
param(
    [Parameter(Mandatory=$true)]
    [string]$Id
)

$PipeName = "claude_agent_$Id"
$RegDir = "C:\tmp\claude_agents"
$RegFile = Join-Path $RegDir "$Id.json"

if (-not (Test-Path $RegDir)) { New-Item -ItemType Directory -Path $RegDir -Force | Out-Null }

# 清除嵌套检测环境变量
Remove-Item Env:CLAUDECODE -ErrorAction SilentlyContinue
Remove-Item Env:CLAUDE_CODE_ENTRYPOINT -ErrorAction SilentlyContinue

# 设置 UTF-8 代码页（解决中文注入乱码）
chcp 65001 | Out-Null

Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Threading;

[StructLayout(LayoutKind.Sequential)]
public struct KEY_EVENT_RECORD
{
    [MarshalAs(UnmanagedType.Bool)]
    public bool bKeyDown;
    public ushort wRepeatCount;
    public ushort wVirtualKeyCode;
    public ushort wVirtualScanCode;
    public char UnicodeChar;
    public uint dwControlKeyState;
}

[StructLayout(LayoutKind.Explicit, Size = 20)]
public struct INPUT_RECORD
{
    [FieldOffset(0)]
    public ushort EventType;
    [FieldOffset(4)]
    public KEY_EVENT_RECORD KeyEvent;
}

public static class ConsoleInjector
{
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool WriteConsoleInput(
        IntPtr hConsoleInput,
        INPUT_RECORD[] lpBuffer,
        uint nLength,
        out uint lpNumberOfEventsWritten);

    private static IntPtr hInput = GetStdHandle(-10);

    public static bool InjectKeys(string text)
    {
        var recs = new INPUT_RECORD[text.Length * 2];
        int idx = 0;
        foreach (char c in text)
        {
            recs[idx].EventType = 1;
            recs[idx].KeyEvent.bKeyDown = true;
            recs[idx].KeyEvent.wRepeatCount = 1;
            recs[idx].KeyEvent.UnicodeChar = c;
            idx++;
            recs[idx].EventType = 1;
            recs[idx].KeyEvent.bKeyDown = false;
            recs[idx].KeyEvent.wRepeatCount = 1;
            recs[idx].KeyEvent.UnicodeChar = c;
            idx++;
        }
        uint written;
        return WriteConsoleInput(hInput, recs, (uint)recs.Length, out written);
    }

    public static bool InjectEnter()
    {
        var recs = new INPUT_RECORD[2];
        recs[0].EventType = 1;
        recs[0].KeyEvent.bKeyDown = true;
        recs[0].KeyEvent.wRepeatCount = 1;
        recs[0].KeyEvent.wVirtualKeyCode = 0x0D;
        recs[0].KeyEvent.UnicodeChar = (char)13;
        recs[1].EventType = 1;
        recs[1].KeyEvent.bKeyDown = false;
        recs[1].KeyEvent.wRepeatCount = 1;
        recs[1].KeyEvent.wVirtualKeyCode = 0x0D;
        recs[1].KeyEvent.UnicodeChar = (char)13;
        uint written;
        return WriteConsoleInput(hInput, recs, 2, out written);
    }

    public static void StartPipeServer(string pipeName)
    {
        var thread = new Thread(() =>
        {
            while (true)
            {
                try
                {
                    using (var pipe = new NamedPipeServerStream(pipeName, PipeDirection.InOut))
                    {
                        pipe.WaitForConnection();
                        using (var reader = new StreamReader(pipe))
                        {
                            string msg = reader.ReadToEnd().Trim();
                            if (!string.IsNullOrEmpty(msg))
                            {
                                InjectKeys(msg);
                                InjectEnter();
                            }
                        }
                    }
                }
                catch (Exception)
                {
                    Thread.Sleep(1000);
                }
            }
        });
        thread.IsBackground = true;
        thread.Start();
    }
}
"@

# 注册
$regInfo = @{
    id        = $Id
    pipe      = $PipeName
    pid       = $PID
    startTime = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
} | ConvertTo-Json
Set-Content -Path $RegFile -Value $regInfo -Encoding UTF8

Register-EngineEvent PowerShell.Exiting -Action {
    $f = "C:\tmp\claude_agents\$($args[0]).json"
    if (Test-Path $f) { Remove-Item $f -Force }
} -MessageData $Id | Out-Null

[ConsoleInjector]::StartPipeServer($PipeName)

Write-Host "=== Agent [$Id] ===" -ForegroundColor Cyan
Write-Host "Pipe: \\.\pipe\$PipeName" -ForegroundColor Yellow
Write-Host "启动 Claude Code..." -ForegroundColor Green
Write-Host ""

# 自动启动 Claude Code
claude --dangerously-skip-permissions
