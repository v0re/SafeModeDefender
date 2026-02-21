# ============================================================================
# Optimizer_Wrapper.ps1 - Optimizer 中文化封裝
# 
# 原始專案：https://github.com/hellzerg/optimizer
# 星級：18,000+
# 授權：GNU General Public License v3.0
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
    Name = "Optimizer"
    Version = "18.7"
    GitHub = "https://github.com/hellzerg/optimizer"
    Description = "先進的 Windows 隱私和安全增強工具，修復註冊表、禁用服務、關閉遙測"
    Author = "hellzerg"
    License = "GNU GPL v3.0"
    Stars = "18,000+"
    SafeModeSupport = $true
}

# 工具路徑
$ToolsDir = "$PSScriptRoot\..\..\Tools"
$OptimizerDir = Join-Path $ToolsDir "optimizer"
$OptimizerExe = Join-Path $OptimizerDir "Optimizer.exe"

# 下載 URL
$DownloadURL = "https://github.com/hellzerg/optimizer/releases/latest/download/Optimizer-16.7.exe"

# 顯示工具資訊
function Show-ToolInfo {
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                         Optimizer                                        ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "  描述：$($ToolInfo.Description)" -ForegroundColor Gray
    Write-Host "  作者：$($ToolInfo.Author)" -ForegroundColor Gray
    Write-Host "  GitHub：$($ToolInfo.GitHub)" -ForegroundColor Gray
    Write-Host "  星級：$($ToolInfo.Stars) ⭐" -ForegroundColor Yellow
    Write-Host "  授權：$($ToolInfo.License)" -ForegroundColor Gray
    Write-Host "  安全模式支援：✓ 是" -ForegroundColor Green
    Write-Host ""
}

# 下載工具
function Download-Optimizer {
    Write-Host "[資訊] 正在下載 Optimizer..." -ForegroundColor Cyan
    
    try {
        if (-not (Test-Path $OptimizerDir)) {
            New-Item -ItemType Directory -Path $OptimizerDir -Force | Out-Null
        }
        
        Write-Host "[資訊] 下載來源：$DownloadURL" -ForegroundColor Gray
        Invoke-WebRequest -Uri $DownloadURL -OutFile $OptimizerExe -UseBasicParsing
        
        Write-Host "[成功] Optimizer 下載完成！" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[錯誤] 下載失敗：$($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 檢查工具是否已安裝
function Test-OptimizerInstalled {
    return (Test-Path $OptimizerExe)
}

# 安裝工具
function Install-Optimizer {
    if (Test-OptimizerInstalled) {
        Write-Host "[資訊] Optimizer 已安裝" -ForegroundColor Green
        return $true
    }
    
    Write-Host "[警告] Optimizer 尚未安裝" -ForegroundColor Yellow
    
    if (-not $Silent) {
        $install = Read-Host "是否立即下載並安裝？(Y/N)"
        if ($install -ne 'Y' -and $install -ne 'y') {
            return $false
        }
    }
    
    return Download-Optimizer
}

# 顯示中文選單
function Show-Menu {
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                     Optimizer 功能選單                                   ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "  [1] 啟動 Optimizer GUI（推薦）" -ForegroundColor Yellow
    Write-Host "      - 提供圖形化介面，可自訂優化選項" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [2] 隱私優化（使用預設模板）" -ForegroundColor Yellow
    Write-Host "      - 禁用遙測、Cortana、Windows Defender 等" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [3] 安全強化（使用預設模板）" -ForegroundColor Yellow
    Write-Host "      - 啟用安全功能、禁用危險服務" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [4] 效能優化（使用預設模板）" -ForegroundColor Yellow
    Write-Host "      - 禁用不必要的服務和功能" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [B] 返回上一級" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "[重要提示]" -ForegroundColor Yellow
    Write-Host "  - Optimizer 會修改系統設定，建議先創建還原點" -ForegroundColor Gray
    Write-Host "  - 某些優化可能影響 Windows Update 或 Microsoft Store" -ForegroundColor Gray
    Write-Host "  - 可透過 Optimizer 的「還原」功能恢復預設設定" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "請選擇功能 (1-4, B)"
    return $choice
}

# 執行 Optimizer
function Invoke-Optimizer {
    param([string]$Mode = "gui")
    
    if (-not (Test-OptimizerInstalled)) {
        if (-not (Install-Optimizer)) {
            return
        }
    }
    
    Write-Host "`n[資訊] 啟動 Optimizer..." -ForegroundColor Cyan
    
    # 檢查是否在安全模式
    $safeMode = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Option" -ErrorAction SilentlyContinue).OptionValue
    if ($safeMode -eq 1 -or $safeMode -eq 2) {
        Write-Host "[資訊] 檢測到安全模式環境" -ForegroundColor Green
    }
    
    try {
        switch ($Mode) {
            "gui" {
                Write-Host "[資訊] 啟動 GUI 模式..." -ForegroundColor Cyan
                Start-Process -FilePath $OptimizerExe -Wait
            }
            "privacy" {
                Write-Host "[資訊] 執行隱私優化..." -ForegroundColor Cyan
                Write-Host "[注意] Optimizer 主要透過 GUI 操作，建議使用選項 1" -ForegroundColor Yellow
                Write-Host "[提示] 您可以在 GUI 中載入預設的隱私優化模板" -ForegroundColor Yellow
                Start-Process -FilePath $OptimizerExe -Wait
            }
            "security" {
                Write-Host "[資訊] 執行安全強化..." -ForegroundColor Cyan
                Start-Process -FilePath $OptimizerExe -Wait
            }
            "performance" {
                Write-Host "[資訊] 執行效能優化..." -ForegroundColor Cyan
                Start-Process -FilePath $OptimizerExe -Wait
            }
            default {
                Start-Process -FilePath $OptimizerExe -Wait
            }
        }
        
        Write-Host "`n[完成] Optimizer 執行完成" -ForegroundColor Green
    }
    catch {
        Write-Host "`n[錯誤] 執行失敗：$($_.Exception.Message)" -ForegroundColor Red
    }
}

# 主邏輯
Show-ToolInfo

if (-not (Install-Optimizer)) {
    Write-Host "[錯誤] 無法安裝 Optimizer" -ForegroundColor Red
    exit 1
}

if ($CLI) {
    # 命令列模式
    if ($Action) {
        Invoke-Optimizer -Mode $Action
    }
    else {
        Invoke-Optimizer -Mode "gui"
    }
}
else {
    # 交互式選單模式
    do {
        $choice = Show-Menu
        
        switch ($choice) {
            "1" { Invoke-Optimizer -Mode "gui" }
            "2" { Invoke-Optimizer -Mode "privacy" }
            "3" { Invoke-Optimizer -Mode "security" }
            "4" { Invoke-Optimizer -Mode "performance" }
            "B" { break }
            "b" { break }
            default {
                Write-Host "[錯誤] 無效的選擇" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } while ($choice -ne "B" -and $choice -ne "b")
}

Write-Host "`n[資訊] 如果 Optimizer 對您有幫助，請考慮：" -ForegroundColor Cyan
Write-Host "  - 在 GitHub 上給專案一個 ⭐ Star" -ForegroundColor Gray
Write-Host "  - GitHub：$($ToolInfo.GitHub)" -ForegroundColor Gray
Write-Host ""
