# PrivescCheck_Wrapper.ps1
param([string]$Action = "", [switch]$CLI, [switch]$Silent)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ToolName = "PrivescCheck"
$DownloadURL = "https://github.com/itm4n/PrivescCheck/releases/latest/download/PrivescCheck.ps1"
$ToolsDir = "$PSScriptRoot\..\..\Tools\PrivescCheck"

if (-not (Test-Path $ToolsDir)) { New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null }

Write-Host "`n[資訊] 正在下載 $ToolName..." -ForegroundColor Yellow
$scriptPath = Join-Path $ToolsDir "PrivescCheck.ps1"

try {
    Invoke-WebRequest -Uri $DownloadURL -OutFile $scriptPath -UseBasicParsing
    Write-Host "[✓] 下載完成" -ForegroundColor Green
    Write-Host "`n[資訊] 正在執行 $ToolName..." -ForegroundColor Yellow
    . $scriptPath
    Invoke-PrivescCheck
} catch {
    Write-Host "[錯誤] 執行失敗：$($_.Exception.Message)" -ForegroundColor Red
}

if (-not $CLI) { Read-Host "`n按 Enter 繼續..." }
