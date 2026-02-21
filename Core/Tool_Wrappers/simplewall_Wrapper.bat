<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>
# ============================================================================
# simplewall_Wrapper.ps1 - simplewall 工具封裝腳本
# 
# 功能：
# - 自動下載和安裝 simplewall
# - 提供中文化交互式介面
# - 支援命令列和圖形化雙模式
# ============================================================================

param(
    [string]$Action = "",
    [switch]$CLI,
    [switch]$Silent
)

# 設定 UTF-8 編碼
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 工具資訊
$ToolName = "simplewall"
$ToolDescription = "輕量級 Windows 過濾平台 (WFP) 管理工具"
$GitHubRepo = "henrypp/simplewall"
$DownloadURL = "https://github.com/henrypp/simplewall/releases/latest/download/simplewall-3.8.3-setup.exe"
$ToolsDir = "$PSScriptRoot\..\..\Tools"
$ToolDir = Join-Path $ToolsDir "simplewall"
$ExecutableName = "simplewall.exe"

# 創建工具目錄
if (-not (Test-Path $ToolDir)) {
    New-Item -ItemType Directory -Path $ToolDir -Force | Out-Null
}

# 顯示工具資訊
function Show-ToolInfo {
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                          $ToolName                                       ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "  描述：$ToolDescription" -ForegroundColor Gray
    Write-Host "  GitHub：https://github.com/$GitHubRepo" -ForegroundColor Gray
    Write-Host "  授權：GPL-3.0" -ForegroundColor Gray
    Write-Host ""
}

# 檢查工具是否已安裝
function Test-ToolInstalled {
    # 檢查程式集中的安裝
    $programFiles = @(
        "${env:ProgramFiles}\simplewall",
        "${env:ProgramFiles(x86)}\simplewall"
    )
    
    foreach ($path in $programFiles) {
        $exePath = Join-Path $path $ExecutableName
        if (Test-Path $exePath) {
            return $exePath
        }
    }
    
    # 檢查本地下載
    $localExe = Join-Path $ToolDir $ExecutableName
    if (Test-Path $localExe) {
        return $localExe
    }
    
    return $null
}

# 下載工具
function Download-Tool {
    Write-Host "`n[資訊] 正在下載 $ToolName..." -ForegroundColor Yellow
    
    $installerPath = Join-Path $ToolDir "simplewall-setup.exe"
    
    try {
        Invoke-WebRequest -Uri $DownloadURL -OutFile $installerPath -UseBasicParsing
        Write-Host "[✓] 下載完成" -ForegroundColor Green
        return $installerPath
    }
    catch {
        Write-Host "[錯誤] 下載失敗：$($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# 安裝工具
function Install-Tool {
    param([string]$InstallerPath)
    
    Write-Host "`n[資訊] 正在安裝 $ToolName..." -ForegroundColor Yellow
    Write-Host "[資訊] 請在安裝程式中完成安裝步驟" -ForegroundColor Gray
    
    try {
        Start-Process -FilePath $InstallerPath -Wait
        Write-Host "[✓] 安裝完成" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[錯誤] 安裝失敗：$($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 執行工具
function Invoke-Tool {
    param([string]$ExePath)
    
    Write-Host "`n[資訊] 正在啟動 $ToolName..." -ForegroundColor Yellow
    
    try {
        Start-Process -FilePath $ExePath
        Write-Host "[✓] $ToolName 已啟動" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[錯誤] 啟動失敗：$($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 主程式
function Main {
    Show-ToolInfo
    
    # 檢查是否已安裝
    $exePath = Test-ToolInstalled
    
    if ($exePath) {
        Write-Host "[✓] $ToolName 已安裝" -ForegroundColor Green
        Write-Host "    路徑：$exePath" -ForegroundColor Gray
        
        if (-not $Silent) {
            $choice = Read-Host "`n是否立即執行 $ToolName？(Y/N)"
            if ($choice -eq "Y" -or $choice -eq "y") {
                Invoke-Tool -ExePath $exePath
            }
        }
    }
    else {
        Write-Host "[!] $ToolName 尚未安裝" -ForegroundColor Yellow
        
        if (-not $Silent) {
            $choice = Read-Host "`n是否立即下載並安裝 $ToolName？(Y/N)"
            if ($choice -ne "Y" -and $choice -ne "y") {
                Write-Host "`n[資訊] 已取消安裝" -ForegroundColor Gray
                return
            }
        }
        
        # 下載
        $installerPath = Download-Tool
        if (-not $installerPath) {
            return
        }
        
        # 安裝
        $installed = Install-Tool -InstallerPath $installerPath
        if ($installed) {
            # 重新檢查安裝路徑
            $exePath = Test-ToolInstalled
            if ($exePath) {
                Write-Host "`n[✓] $ToolName 已成功安裝並可使用" -ForegroundColor Green
                
                if (-not $Silent) {
                    $choice = Read-Host "`n是否立即執行 $ToolName？(Y/N)"
                    if ($choice -eq "Y" -or $choice -eq "y") {
                        Invoke-Tool -ExePath $exePath
                    }
                }
            }
        }
    }
}

# 執行主程式
Main

if (-not $CLI) {
    Write-Host "`n按任意鍵繼續..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
