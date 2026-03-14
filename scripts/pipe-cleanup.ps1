# pipe-cleanup.ps1 - 优雅关闭所有 agent（先退出 claude，再杀进程树）
param(
    [string]$TargetId  # 可选，指定关闭某个 agent；不指定则关闭全部
)

$RegDir = "C:\tmp\claude_agents"
$SendScript = Join-Path $PSScriptRoot "pipe-send.ps1"

$files = if ($TargetId) {
    Get-ChildItem "$RegDir\$TargetId.json" -ErrorAction SilentlyContinue
} else {
    Get-ChildItem "$RegDir\*.json" -ErrorAction SilentlyContinue
}

if (-not $files) {
    Write-Host "没有在线的 agent。" -ForegroundColor DarkGray
    return
}

foreach ($f in $files) {
    $info = Get-Content $f.FullName -Raw | ConvertFrom-Json

    # 1. 尝试通过 pipe 发送 /exit 给 Claude Code
    try {
        $pipe = [System.IO.Pipes.NamedPipeClientStream]::new(".", $info.pipe, "InOut")
        $pipe.Connect(2000)
        $writer = [System.IO.StreamWriter]::new($pipe)
        $writer.Write("/exit")
        $writer.Flush()
        $writer.Close()
        $pipe.Close()
        Write-Host "[$($info.id)] 已发送 /exit" -ForegroundColor Cyan
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "[$($info.id)] pipe 不可用，直接杀进程" -ForegroundColor DarkYellow
    }

    # 2. 杀掉进程树（父进程 + 所有子进程）
    $parentPid = $info.pid
    try {
        $children = Get-CimInstance Win32_Process |
            Where-Object { $_.ParentProcessId -eq $parentPid } |
            Select-Object -ExpandProperty ProcessId

        foreach ($childPid in $children) {
            # 递归杀子进程的子进程
            $grandchildren = Get-CimInstance Win32_Process |
                Where-Object { $_.ParentProcessId -eq $childPid } |
                Select-Object -ExpandProperty ProcessId
            foreach ($gc in $grandchildren) {
                Stop-Process -Id $gc -Force -ErrorAction SilentlyContinue
            }
            Stop-Process -Id $childPid -Force -ErrorAction SilentlyContinue
        }
        Stop-Process -Id $parentPid -Force -ErrorAction SilentlyContinue
        Write-Host "[$($info.id)] 已杀掉进程树 (pid=$parentPid)" -ForegroundColor Yellow
    } catch {
        Write-Host "[$($info.id)] 进程已退出" -ForegroundColor DarkGray
    }

    # 3. 清理注册文件
    Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
}
