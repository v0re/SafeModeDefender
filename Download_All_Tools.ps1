<#
.SYNOPSIS
    一鍵下載所有外部工具

.DESCRIPTION
    自動下載 SafeModeDefender 所需的所有外部工具
    包括：ClamAV, WinUtil, TestDisk, Optimizer, simplewall, PrivescCheck
    
.NOTES
    Author: SafeModeDefender Team
    Version: 1.0
#>

[CmdletBinding()]
param()

# 設定輸出編碼為 UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 設定下載目錄
$DownloadDir = Join-Path $PSScriptRoot "External_Tools"
if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
}

Write-Host "╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    一鍵下載所有外部工具                                 ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 工具列表
$tools = @(
    @{
        Name = "ClamAV"
        Url = "https://www.clamav.net/downloads/production/clamav-1.4.1.win.x64.zip"
        FileName = "clamav-1.4.1.win.x64.zip"
        Description = "開源防毒引擎"
    },
    @{
        Name = "Chris Titus Tech's Windows Utility"
        Url = "https://github.com/ChrisTitusTech/winutil/releases/latest/download/winutil.ps1"
        FileName = "winutil.ps1"
        Description = "全能 Windows 工具"
    },
    @{
        Name = "TestDisk & PhotoRec"
        Url = "https://www.cgsecurity.org/testdisk-7.2.win64.zip"
        FileName = "testdisk-7.2.win64.zip"
        Description = "資料救援工具"
    },
    @{
        Name = "Optimizer"
        Url = "https://github.com/hellzerg/optimizer/releases/download/16.7/Optimizer-16.7.exe"
        FileName = "Optimizer-16.7.exe"
        Description = "隱私與安全增強工具"
    },
    @{
        Name = "simplewall"
        Url = "https://github.com/henrypp/simplewall/releases/download/v.3.8.3/simplewall-3.8.3-bin.zip"
        FileName = "simplewall-3.8.3-bin.zip"
        Description = "輕量級防火牆管理工具"
    },
    @{
        Name = "PrivescCheck"
        Url = "https://github.com/itm4n/PrivescCheck/raw/master/PrivescCheck.ps1"
        FileName = "PrivescCheck.ps1"
        Description = "權限提升漏洞檢測工具"
    }
)

# 下載函數
function Download-Tool {
    param(
        [string]$Name,
        [string]$Url,
        [string]$FileName,
        [string]$Description
    )
    
    $FilePath = Join-Path $DownloadDir $FileName
    
    Write-Host "[$Name]" -ForegroundColor Yellow
    Write-Host "  描述: $Description" -ForegroundColor Gray
    Write-Host "  下載中..." -ForegroundColor Gray -NoNewline
    
    try {
        # 檢查檔案是否已存在
        if (Test-Path $FilePath) {
            Write-Host " [已存在，跳過]" -ForegroundColor Green
            return $true
        }
        
        # 下載檔案
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $FilePath -UseBasicParsing -ErrorAction Stop
        $ProgressPreference = 'Continue'
        
        # 驗證檔案大小
        $FileSize = (Get-Item $FilePath).Length
        if ($FileSize -gt 0) {
            $FileSizeMB = [math]::Round($FileSize / 1MB, 2)
            Write-Host " [完成] ($FileSizeMB MB)" -ForegroundColor Green
            return $true
        } else {
            Write-Host " [失敗：檔案大小為 0]" -ForegroundColor Red
            Remove-Item $FilePath -Force -ErrorAction SilentlyContinue
            return $false
        }
    }
    catch {
        Write-Host " [失敗]" -ForegroundColor Red
        Write-Host "  錯誤: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 開始下載
$successCount = 0
$failCount = 0

foreach ($tool in $tools) {
    $result = Download-Tool -Name $tool.Name -Url $tool.Url -FileName $tool.FileName -Description $tool.Description
    if ($result) {
        $successCount++
    } else {
        $failCount++
    }
    Write-Host ""
}

# 顯示結果
Write-Host "══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "下載完成！" -ForegroundColor Green
Write-Host "  成功: $successCount" -ForegroundColor Green
Write-Host "  失敗: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host "  目錄: $DownloadDir" -ForegroundColor Cyan
Write-Host ""

# 解壓縮 ZIP 檔案
Write-Host "是否要自動解壓縮 ZIP 檔案？(Y/N)" -ForegroundColor Yellow -NoNewline
$response = Read-Host " "

if ($response -eq 'Y' -or $response -eq 'y') {
    Write-Host ""
    Write-Host "解壓縮中..." -ForegroundColor Cyan
    
    $zipFiles = Get-ChildItem -Path $DownloadDir -Filter "*.zip"
    foreach ($zipFile in $zipFiles) {
        $extractPath = Join-Path $DownloadDir $zipFile.BaseName
        
        if (-not (Test-Path $extractPath)) {
            Write-Host "  解壓縮: $($zipFile.Name)..." -ForegroundColor Gray -NoNewline
            try {
                Expand-Archive -Path $zipFile.FullName -DestinationPath $extractPath -Force
                Write-Host " [完成]" -ForegroundColor Green
            }
            catch {
                Write-Host " [失敗]" -ForegroundColor Red
            }
        } else {
            Write-Host "  $($zipFile.Name) [已解壓縮，跳過]" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "所有工具已準備就緒！您現在可以離線使用 SafeModeDefender。" -ForegroundColor Green
Write-Host ""
