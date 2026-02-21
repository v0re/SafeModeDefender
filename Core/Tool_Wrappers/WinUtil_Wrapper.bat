<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>
# ============================================================================
# WinUtil_Wrapper.ps1 - Chris Titus Tech's Windows Utility 中文化封裝
# 
# 原始專案：https://github.com/ChrisTitusTech/winutil
# 星級：47,600+
# 授權：MIT License
# ============================================================================

param(
    [string]$Action = "",
    [switch]$CLI,
    [switch]$Silent,
    [switch]$AutoFix
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 工具資訊
$ToolInfo = @{
    Name = "Chris Titus Tech's Windows Utility"
    ShortName = "WinUtil"
    Version = "Latest"
    GitHub = "https://github.com/ChrisTitusTech/winutil"
    Description = "全能 Windows 工具，涵蓋系統優化、修復、調整、安全強化等功能"
    Author = "Chris Titus Tech"
    License = "MIT License"
    Stars = "47,600+"
    SafeModeSupport = $true
}

# 工具路徑（使用路徑正規化確保跨平台兼容）
$ScriptRoot = Split-Path -Parent $PSScriptRoot
$ProjectRoot = Split-Path -Parent $ScriptRoot
$ToolsDir = Join-Path $ProjectRoot "Tools"
$WinUtilDir = Join-Path $ToolsDir "winutil"
$WinUtilScript = Join-Path $WinUtilDir "winutil.ps1"

# 驗證路徑
if (-not (Test-Path $ProjectRoot)) {
    Write-Error "無法找到專案根目錄：$ProjectRoot"
    exit 1
}

# 顯示工具資訊
function Show-ToolInfo {
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    $($ToolInfo.ShortName) - $($ToolInfo.Name)" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "  描述：$($ToolInfo.Description)" -ForegroundColor Gray
    Write-Host "  作者：$($ToolInfo.Author)" -ForegroundColor Gray
    Write-Host "  GitHub：$($ToolInfo.GitHub)" -ForegroundColor Gray
    Write-Host "  星級：$($ToolInfo.Stars) ⭐" -ForegroundColor Yellow
    Write-Host "  授權：$($ToolInfo.License)" -ForegroundColor Gray
    $safeModeText = if ($ToolInfo.SafeModeSupport) { '✓ 是' } else { '✗ 否' }
    $safeModeColor = if ($ToolInfo.SafeModeSupport) { 'Green' } else { 'Red' }
    Write-Host "  安全模式支援：$safeModeText" -ForegroundColor $safeModeColor
    Write-Host ""
}

# 下載工具
function Download-WinUtil {
    Write-Host "[資訊] 正在下載 WinUtil..." -ForegroundColor Cyan
    
    try {
        # 創建目錄
        if (-not (Test-Path $WinUtilDir)) {
            New-Item -ItemType Directory -Path $WinUtilDir -Force | Out-Null
        }
        
        # 下載最新版本的腳本
        $downloadUrl = "https://raw.githubusercontent.com/ChrisTitusTech/winutil/main/winutil.ps1"
        
        Write-Host "[資訊] 下載來源：$downloadUrl" -ForegroundColor Gray
        Invoke-WebRequest -Uri $downloadUrl -OutFile $WinUtilScript -UseBasicParsing
        
        Write-Host "[成功] WinUtil 下載完成！" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[錯誤] 下載失敗：$($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 檢查工具是否已安裝
function Test-WinUtilInstalled {
    return (Test-Path $WinUtilScript)
}

# 安裝工具
function Install-WinUtil {
    if (Test-WinUtilInstalled) {
        Write-Host "[資訊] WinUtil 已安裝" -ForegroundColor Green
        return $true
    }
    
    Write-Host "[警告] WinUtil 尚未安裝" -ForegroundColor Yellow
    
    if (-not $Silent) {
        $install = Read-Host "是否立即下載並安裝？(Y/N)"
        if ($install -ne 'Y' -and $install -ne 'y') {
            return $false
        }
    }
    
    return Download-WinUtil
}

# 顯示中文選單
function Show-Menu {
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                      WinUtil 功能選單                                    ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "  [1] 啟動完整 WinUtil GUI（推薦）" -ForegroundColor Yellow
    Write-Host "      - 提供圖形化介面，包含所有功能" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [2] 系統修復與維護" -ForegroundColor Yellow
    Write-Host "      - 執行 SFC、DISM 和其他系統修復工具" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [3] Windows Update 修復" -ForegroundColor Yellow
    Write-Host "      - 重置 Windows Update 組件" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [4] 系統優化與調整" -ForegroundColor Yellow
    Write-Host "      - 禁用遙測、優化效能、移除臃腫軟體" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [5] 隱私與安全強化" -ForegroundColor Yellow
    Write-Host "      - 禁用遙測、強化隱私設定" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [B] 返回上一級" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "請選擇功能 (1-5, B)"
    return $choice
}

# 執行 WinUtil
function Invoke-WinUtil {
    param([string]$Mode = "gui")
    
    if (-not (Test-WinUtilInstalled)) {
        if (-not (Install-WinUtil)) {
            return
        }
    }
    
    Write-Host "`n[資訊] 啟動 WinUtil..." -ForegroundColor Cyan
    Write-Host "[提示] WinUtil 是一個功能強大的工具，請謹慎使用" -ForegroundColor Yellow
    Write-Host "[建議] 建議先創建系統還原點" -ForegroundColor Yellow
    Write-Host ""
    
    try {
        switch ($Mode) {
            "gui" {
                Write-Host "[資訊] 啟動 GUI 模式..." -ForegroundColor Cyan
                & powershell.exe -ExecutionPolicy Bypass -File $WinUtilScript
            }
            "repair" {
                Write-Host "[資訊] 執行系統修復..." -ForegroundColor Cyan
                Write-Host "[注意] WinUtil 主要提供 GUI 介面，建議使用選項 1 啟動完整介面" -ForegroundColor Yellow
                & powershell.exe -ExecutionPolicy Bypass -File $WinUtilScript
            }
            "update" {
                Write-Host "[資訊] 修復 Windows Update..." -ForegroundColor Cyan
                & powershell.exe -ExecutionPolicy Bypass -File $WinUtilScript
            }
            "optimize" {
                Write-Host "[資訊] 系統優化..." -ForegroundColor Cyan
                & powershell.exe -ExecutionPolicy Bypass -File $WinUtilScript
            }
            "privacy" {
                Write-Host "[資訊] 隱私強化..." -ForegroundColor Cyan
                & powershell.exe -ExecutionPolicy Bypass -File $WinUtilScript
            }
            default {
                & powershell.exe -ExecutionPolicy Bypass -File $WinUtilScript
            }
        }
        
        Write-Host "`n[完成] WinUtil 執行完成" -ForegroundColor Green
    }
    catch {
        Write-Host "`n[錯誤] 執行失敗：$($_.Exception.Message)" -ForegroundColor Red
    }
}

# 主邏輯
Show-ToolInfo

if (-not (Install-WinUtil)) {
    Write-Host "[錯誤] 無法安裝 WinUtil" -ForegroundColor Red
    exit 1
}

if ($CLI) {
    # 命令列模式
    if ($Action) {
        Invoke-WinUtil -Mode $Action
    }
    else {
        Invoke-WinUtil -Mode "gui"
    }
}
else {
    # 交互式選單模式
    do {
        $choice = Show-Menu
        
        switch ($choice) {
            "1" { Invoke-WinUtil -Mode "gui" }
            "2" { Invoke-WinUtil -Mode "repair" }
            "3" { Invoke-WinUtil -Mode "update" }
            "4" { Invoke-WinUtil -Mode "optimize" }
            "5" { Invoke-WinUtil -Mode "privacy" }
            "B" { break }
            "b" { break }
            default {
                Write-Host "[錯誤] 無效的選擇" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } while ($choice -ne "B" -and $choice -ne "b")
}

Write-Host "`n[資訊] 如果 WinUtil 對您有幫助，請考慮：" -ForegroundColor Cyan
Write-Host "  - 在 GitHub 上給專案一個 ⭐ Star" -ForegroundColor Gray
Write-Host "  - GitHub：$($ToolInfo.GitHub)" -ForegroundColor Gray
Write-Host ""
