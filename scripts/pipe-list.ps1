# pipe-list.ps1 - 列出所有在线的 agent
$RegDir = "C:\tmp\claude_agents"

if (-not (Test-Path $RegDir)) {
    Write-Host "没有注册的 agent。" -ForegroundColor Yellow
    return
}

$files = Get-ChildItem -Path $RegDir -Filter "*.json" -ErrorAction SilentlyContinue
if ($files.Count -eq 0) {
    Write-Host "没有在线的 agent。" -ForegroundColor Yellow
    return
}

Write-Host "=== 在线 Agent ===" -ForegroundColor Cyan
foreach ($f in $files) {
    $info = Get-Content $f.FullName -Raw | ConvertFrom-Json
    $proc = Get-Process -Id $info.pid -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "  [$($info.id)] pipe=$($info.pipe)  pid=$($info.pid)  started=$($info.startTime)" -ForegroundColor Green
    } else {
        # 进程已死，清理注册
        Remove-Item $f.FullName -Force
        Write-Host "  [$($info.id)] (已离线，已清理)" -ForegroundColor DarkGray
    }
}
