<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>
# ============================================================================
# ClamAV_Wrapper.ps1 - ClamAV 防毒引擎封裝腳本
# 
# 功能：
# - 提供中文化的 ClamAV 操作介面
# - 支援離線模式（使用預先下載的病毒資料庫）
# - 自動檢測資料庫狀態和時效性
# - 提供病毒掃描、資料庫更新等功能
# ============================================================================

param(
    [string]$Action = "",
    [string]$ScanPath = "",
    [switch]$CLI,
    [switch]$Silent
)

# 設定 UTF-8 編碼
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ClamAV 工具資訊
$ToolInfo = @{
    Name = "ClamAV"
    FullName = "Clam AntiVirus"
    Description = "開源跨平台防毒引擎，檢測木馬、病毒、惡意軟體"
    GitHub = "https://github.com/Cisco-Talos/clamav"
    Stars = "6,256+"
    License = "GPL-2.0"
    Author = "Cisco Talos"
}

# 路徑定義
$ToolsDir = "$PSScriptRoot\..\..\Tools"
$ClamAVDir = Join-Path $ToolsDir "ClamAV"
$BinDir = Join-Path $ClamAVDir "bin"
$DatabaseDir = Join-Path $ClamAVDir "database"
$LogsDir = Join-Path $ClamAVDir "logs"

# 執行檔路徑
$ClamscanExe = Join-Path $BinDir "clamscan.exe"
$FreshclamExe = Join-Path $BinDir "freshclam.exe"

# 病毒資料庫檔案
$DatabaseFiles = @(
    "main.cvd",
    "daily.cvd",
    "bytecode.cvd"
)

# 檢查 ClamAV 是否已安裝
function Test-ClamAVInstalled {
    return (Test-Path $ClamscanExe)
}

# 檢查病毒資料庫狀態
function Get-DatabaseStatus {
    $status = @{
        Exists = $false
        Files = @()
        TotalSize = 0
        OldestDate = $null
        Age = $null
        IsOutdated = $false
    }
    
    if (-not (Test-Path $DatabaseDir)) {
        return $status
    }
    
    $status.Exists = $true
    $oldestDate = Get-Date
    
    foreach ($file in $DatabaseFiles) {
        $filePath = Join-Path $DatabaseDir $file
        
        if (Test-Path $filePath) {
            $fileInfo = Get-Item $filePath
            $status.Files += @{
                Name = $file
                Size = $fileInfo.Length
                LastModified = $fileInfo.LastWriteTime
            }
            
            $status.TotalSize += $fileInfo.Length
            
            if ($fileInfo.LastWriteTime -lt $oldestDate) {
                $oldestDate = $fileInfo.LastWriteTime
            }
        }
    }
    
    if ($status.Files.Count -gt 0) {
        $status.OldestDate = $oldestDate
        $status.Age = (Get-Date) - $oldestDate
        $status.IsOutdated = $status.Age.Days -gt 30  # 超過 30 天視為過期
    }
    
    return $status
}

# 顯示工具資訊
function Show-ToolInfo {
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                          ClamAV 防毒引擎                                 ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "  工具名稱：$($ToolInfo.FullName)" -ForegroundColor Yellow
    Write-Host "  描述：$($ToolInfo.Description)" -ForegroundColor Gray
    Write-Host "  GitHub：$($ToolInfo.GitHub)" -ForegroundColor Gray
    Write-Host "  星級：$($ToolInfo.Stars) ⭐" -ForegroundColor Gray
    Write-Host "  授權：$($ToolInfo.License)" -ForegroundColor Gray
    Write-Host "  作者：$($ToolInfo.Author)" -ForegroundColor Gray
    Write-Host ""
    
    # 檢查安裝狀態
    if (Test-ClamAVInstalled) {
        Write-Host "  安裝狀態：✓ 已安裝" -ForegroundColor Green
        
        # 檢查資料庫狀態
        $dbStatus = Get-DatabaseStatus
        
        if ($dbStatus.Exists -and $dbStatus.Files.Count -eq $DatabaseFiles.Count) {
            $sizeInMB = [math]::Round($dbStatus.TotalSize / 1MB, 2)
            $ageText = "$($dbStatus.Age.Days) 天前"
            
            if ($dbStatus.IsOutdated) {
                Write-Host "  資料庫狀態：⚠ 已過期（$ageText，$sizeInMB MB）" -ForegroundColor Yellow
                Write-Host "  建議：病毒資料庫已超過 30 天，建議更新" -ForegroundColor Yellow
            }
            else {
                Write-Host "  資料庫狀態：✓ 正常（$ageText，$sizeInMB MB）" -ForegroundColor Green
            }
        }
        elseif ($dbStatus.Exists) {
            Write-Host "  資料庫狀態：⚠ 不完整（缺少部分檔案）" -ForegroundColor Yellow
        }
        else {
            Write-Host "  資料庫狀態：✗ 未安裝" -ForegroundColor Red
            Write-Host "  警告：沒有病毒資料庫，ClamAV 無法運作" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  安裝狀態：✗ 未安裝" -ForegroundColor Red
    }
    
    Write-Host ""
}

# 安裝 ClamAV
function Install-ClamAV {
    Write-Host "`n[資訊] 正在安裝 ClamAV..." -ForegroundColor Cyan
    
    # 檢測網路
    $hasNetwork = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
    
    if (-not $hasNetwork) {
        Write-Host "[錯誤] 無網路連線，無法下載 ClamAV" -ForegroundColor Red
        Write-Host "[提示] 請下載完整版的 SafeModeDefender，或在有網路的環境下執行" -ForegroundColor Yellow
        return $false
    }
    
    # 創建目錄
    if (-not (Test-Path $ClamAVDir)) {
        New-Item -ItemType Directory -Path $ClamAVDir -Force | Out-Null
    }
    if (-not (Test-Path $BinDir)) {
        New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    }
    if (-not (Test-Path $DatabaseDir)) {
        New-Item -ItemType Directory -Path $DatabaseDir -Force | Out-Null
    }
    if (-not (Test-Path $LogsDir)) {
        New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
    }
    
    # 下載 ClamAV（這裡簡化處理，實際應該從官方下載）
    Write-Host "[資訊] 下載 ClamAV 執行檔..." -ForegroundColor Cyan
    Write-Host "[提示] 請手動從 https://www.clamav.net/downloads 下載 Windows 版本" -ForegroundColor Yellow
    Write-Host "[提示] 並將執行檔放置到：$BinDir" -ForegroundColor Yellow
    
    return $false
}

# 更新病毒資料庫
function Update-VirusDatabase {
    Write-Host "`n[資訊] 正在更新病毒資料庫..." -ForegroundColor Cyan
    
    # 檢測網路
    $hasNetwork = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
    
    if (-not $hasNetwork) {
        Write-Host "[錯誤] 無網路連線，無法更新資料庫" -ForegroundColor Red
        Write-Host "[提示] 請在有網路的環境下執行更新，或使用含網路功能的安全模式" -ForegroundColor Yellow
        Write-Host "[替代方案] 使用 Offline_Resources_Manager.ps1 更新資料庫" -ForegroundColor Yellow
        return $false
    }
    
    # 使用 freshclam 更新
    if (Test-Path $FreshclamExe) {
        Write-Host "[資訊] 使用 freshclam 更新資料庫..." -ForegroundColor Cyan
        
        try {
            & $FreshclamExe --datadir=$DatabaseDir
            Write-Host "[成功] 病毒資料庫更新完成！" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "[錯誤] 更新失敗：$($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    else {
        Write-Host "[錯誤] freshclam.exe 不存在" -ForegroundColor Red
        return $false
    }
}

# 執行病毒掃描
function Invoke-VirusScan {
    param([string]$Path)
    
    # 檢查 ClamAV
    if (-not (Test-ClamAVInstalled)) {
        Write-Host "[錯誤] ClamAV 未安裝" -ForegroundColor Red
        return
    }
    
    # 檢查資料庫
    $dbStatus = Get-DatabaseStatus
    if (-not $dbStatus.Exists -or $dbStatus.Files.Count -eq 0) {
        Write-Host "[錯誤] 病毒資料庫不存在，無法執行掃描" -ForegroundColor Red
        Write-Host "[提示] 請先更新資料庫或使用完整版的 SafeModeDefender" -ForegroundColor Yellow
        return
    }
    
    if ($dbStatus.IsOutdated) {
        Write-Host "[警告] 病毒資料庫已過期 $($dbStatus.Age.Days) 天" -ForegroundColor Yellow
        Write-Host "[提示] 掃描結果可能無法檢測到最新的威脅" -ForegroundColor Yellow
        Write-Host ""
    }
    
    # 確定掃描路徑
    if (-not $Path) {
        $Path = Read-Host "請輸入要掃描的路徑（留空掃描整個 C 磁碟機）"
        if (-not $Path) {
            $Path = "C:\"
        }
    }
    
    if (-not (Test-Path $Path)) {
        Write-Host "[錯誤] 路徑不存在：$Path" -ForegroundColor Red
        return
    }
    
    Write-Host "`n[資訊] 開始掃描：$Path" -ForegroundColor Cyan
    Write-Host "[提示] 這可能需要較長時間，請耐心等待..." -ForegroundColor Yellow
    Write-Host ""
    
    # 生成日誌檔案名
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFile = Join-Path $LogsDir "scan_$timestamp.log"
    
    # 執行掃描
    try {
        & $ClamscanExe --recursive --database=$DatabaseDir --log=$logFile $Path
        
        Write-Host "`n[完成] 掃描完成！" -ForegroundColor Green
        Write-Host "[資訊] 日誌檔案：$logFile" -ForegroundColor Cyan
        
        # 顯示日誌摘要
        if (Test-Path $logFile) {
            $logContent = Get-Content $logFile -Tail 20
            Write-Host "`n掃描摘要：" -ForegroundColor Cyan
            $logContent | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        }
    }
    catch {
        Write-Host "[錯誤] 掃描失敗：$($_.Exception.Message)" -ForegroundColor Red
    }
}

# 顯示選單
function Show-Menu {
    Write-Host "`n請選擇功能：" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] 快速掃描（使用者目錄）" -ForegroundColor Yellow
    Write-Host "  [2] 完整掃描（整個 C 磁碟機）" -ForegroundColor Yellow
    Write-Host "  [3] 自訂路徑掃描" -ForegroundColor Yellow
    Write-Host "  [4] 更新病毒資料庫" -ForegroundColor Yellow
    Write-Host "  [5] 檢查資料庫狀態" -ForegroundColor Yellow
    Write-Host "  [Q] 返回" -ForegroundColor Gray
    Write-Host ""
}

# 主邏輯
Show-ToolInfo

# 檢查安裝
if (-not (Test-ClamAVInstalled)) {
    if (-not $Silent) {
        $install = Read-Host "ClamAV 尚未安裝，是否立即安裝？(Y/N)"
        if ($install -eq 'Y' -or $install -eq 'y') {
            Install-ClamAV
        }
        else {
            Write-Host "[資訊] 已取消" -ForegroundColor Gray
            exit 0
        }
    }
    else {
        Write-Host "[錯誤] ClamAV 未安裝且處於靜默模式" -ForegroundColor Red
        exit 1
    }
}

# CLI 模式
if ($CLI -and $Action) {
    switch ($Action.ToLower()) {
        "scan" {
            Invoke-VirusScan -Path $ScanPath
        }
        "update" {
            Update-VirusDatabase
        }
        "status" {
            $dbStatus = Get-DatabaseStatus
            if ($dbStatus.Exists) {
                Write-Host "資料庫狀態：正常" -ForegroundColor Green
                Write-Host "檔案數量：$($dbStatus.Files.Count)" -ForegroundColor Gray
                Write-Host "總大小：$([math]::Round($dbStatus.TotalSize / 1MB, 2)) MB" -ForegroundColor Gray
                Write-Host "最後更新：$($dbStatus.OldestDate)" -ForegroundColor Gray
            }
            else {
                Write-Host "資料庫狀態：不存在" -ForegroundColor Red
            }
        }
        default {
            Write-Host "[錯誤] 未知的動作：$Action" -ForegroundColor Red
            Write-Host "有效的動作：scan, update, status" -ForegroundColor Yellow
        }
    }
    exit 0
}

# 交互模式
do {
    Show-Menu
    $choice = Read-Host "請選擇"
    
    switch ($choice) {
        "1" {
            $userProfile = $env:USERPROFILE
            Invoke-VirusScan -Path $userProfile
        }
        "2" {
            Invoke-VirusScan -Path "C:\"
        }
        "3" {
            Invoke-VirusScan
        }
        "4" {
            Update-VirusDatabase
        }
        "5" {
            $dbStatus = Get-DatabaseStatus
            
            Write-Host "`n病毒資料庫狀態：" -ForegroundColor Cyan
            
            if ($dbStatus.Exists -and $dbStatus.Files.Count -gt 0) {
                Write-Host "  檔案數量：$($dbStatus.Files.Count) / $($DatabaseFiles.Count)" -ForegroundColor Gray
                Write-Host "  總大小：$([math]::Round($dbStatus.TotalSize / 1MB, 2)) MB" -ForegroundColor Gray
                Write-Host "  最後更新：$($dbStatus.OldestDate)" -ForegroundColor Gray
                Write-Host "  資料庫年齡：$($dbStatus.Age.Days) 天" -ForegroundColor Gray
                
                Write-Host "`n  檔案詳情：" -ForegroundColor Cyan
                foreach ($file in $dbStatus.Files) {
                    $sizeInMB = [math]::Round($file.Size / 1MB, 2)
                    Write-Host "    - $($file.Name): $sizeInMB MB (更新於 $($file.LastModified))" -ForegroundColor Gray
                }
            }
            else {
                Write-Host "  資料庫不存在或不完整" -ForegroundColor Red
            }
            
            Write-Host ""
            Read-Host "按 Enter 繼續..."
        }
        "Q" {
            Write-Host "返回主選單" -ForegroundColor Gray
        }
        default {
            Write-Host "[錯誤] 無效的選擇" -ForegroundColor Red
        }
    }
} while ($choice -ne "Q")
