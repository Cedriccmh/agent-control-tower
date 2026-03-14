# pipe-send.ps1 - 向指定 agent 发送命令
# 用法: .\pipe-send.ps1 -Id agent1 -Message "echo hello"
param(
    [Parameter(Mandatory=$true)]
    [string]$Id,

    [Parameter(Mandatory=$true)]
    [string]$Message,

    [int]$TimeoutMs = 5000
)

$PipeName = "claude_agent_$Id"

try {
    $pipe = [System.IO.Pipes.NamedPipeClientStream]::new(".", $PipeName, "InOut")
    $pipe.Connect($TimeoutMs)
    $writer = [System.IO.StreamWriter]::new($pipe)
    $writer.Write($Message)
    $writer.Flush()
    $writer.Close()
    $pipe.Close()
    Write-Host "[OK -> $Id] $Message" -ForegroundColor Green
}
catch {
    Write-Host "[错误 -> $Id] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
