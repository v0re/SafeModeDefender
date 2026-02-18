# ============================================================================
# TestDisk_Wrapper.ps1 - TestDisk & PhotoRec 中文化封裝
# 
# 原始專案：https://github.com/cgsecurity/testdisk
# 星級：2,300+
# 授權：GNU General Public License v2.0
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
    Name = "TestDisk & PhotoRec"
    Version = "7.2-WIP"
    GitHub = "https://github.com/cgsecurity/testdisk"
    Website = "https://www.cgsecurity.org"
    Description = "強大的磁碟分區恢復和引導扇區修復工具，支援 480+ 檔案格式恢復"
    Author = "Christophe GRENIER"
    License = "GNU GPL v2.0"
    Stars = "2,300+"
    SafeModeSupport = $true
}

# 工具路徑
$ToolsDir = "$PSScriptRoot\..\..\Tools"
$TestDiskDir = Join-Path $ToolsDir "testdisk"
$TestDiskExe = Join-Path $TestDiskDir "testdisk_win.exe"
$PhotoRecExe = Join-Path $TestDiskDir "photorec_win.exe"
$QPhotoRecExe = Join-Path $TestDiskDir "qphotorec_win.exe"

# 下載 URL
$DownloadURL = "https://www.cgsecurity.org/testdisk-7.2-WIP.win.zip"

# 顯示工具資訊
function Show-ToolInfo {
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    TestDisk & PhotoRec                                   ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "  描述：$($ToolInfo.Description)" -ForegroundColor Gray
    Write-Host "  作者：$($ToolInfo.Author)" -ForegroundColor Gray
    Write-Host "  網站：$($ToolInfo.Website)" -ForegroundColor Gray
    Write-Host "  GitHub：$($ToolInfo.GitHub)" -ForegroundColor Gray
    Write-Host "  星級：$($ToolInfo.Stars) ⭐" -ForegroundColor Yellow
    Write-Host "  授權：$($ToolInfo.License)" -ForegroundColor Gray
    Write-Host "  安全模式支援：✓ 是" -ForegroundColor Green
    Write-Host ""
}

# 下載工具
function Download-TestDisk {
    Write-Host "[資訊] 正在下載 TestDisk..." -ForegroundColor Cyan
    
    try {
        if (-not (Test-Path $TestDiskDir)) {
            New-Item -ItemType Directory -Path $TestDiskDir -Force | Out-Null
        }
        
        $zipPath = Join-Path $TestDiskDir "testdisk.zip"
        
        Write-Host "[資訊] 下載來源：$DownloadURL" -ForegroundColor Gray
        Invoke-WebRequest -Uri $DownloadURL -OutFile $zipPath -UseBasicParsing
        
        Write-Host "[資訊] 正在解壓縮..." -ForegroundColor Cyan
        Expand-Archive -Path $zipPath -DestinationPath $TestDiskDir -Force
        
        # 移動檔案到正確位置
        $extractedDir = Get-ChildItem -Path $TestDiskDir -Directory | Where-Object { $_.Name -like "testdisk*" } | Select-Object -First 1
        if ($extractedDir) {
            Get-ChildItem -Path $extractedDir.FullName | Move-Item -Destination $TestDiskDir -Force
            Remove-Item -Path $extractedDir.FullName -Recurse -Force
        }
        
        Remove-Item -Path $zipPath -Force
        
        Write-Host "[成功] TestDisk 下載完成！" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[錯誤] 下載失敗：$($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 檢查工具是否已安裝
function Test-TestDiskInstalled {
    return (Test-Path $TestDiskExe) -and (Test-Path $PhotoRecExe)
}

# 安裝工具
function Install-TestDisk {
    if (Test-TestDiskInstalled) {
        Write-Host "[資訊] TestDisk 已安裝" -ForegroundColor Green
        return $true
    }
    
    Write-Host "[警告] TestDisk 尚未安裝" -ForegroundColor Yellow
    
    if (-not $Silent) {
        $install = Read-Host "是否立即下載並安裝？(Y/N)"
        if ($install -ne 'Y' -and $install -ne 'y') {
            return $false
        }
    }
    
    return Download-TestDisk
}

# 顯示中文選單
function Show-Menu {
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                   TestDisk & PhotoRec 功能選單                           ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "  【TestDisk - 磁碟分區修復】" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] 恢復丟失的分區" -ForegroundColor Yellow
    Write-Host "      - 掃描並恢復被刪除或丟失的磁碟分區" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [2] 修復引導扇區 (MBR/Boot Sector)" -ForegroundColor Yellow
    Write-Host "      - 修復損壞的主引導記錄或引導扇區" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [3] 修復分區表" -ForegroundColor Yellow
    Write-Host "      - 重建或修復損壞的分區表" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [4] TestDisk 進階模式" -ForegroundColor Yellow
    Write-Host "      - 直接啟動 TestDisk，手動操作所有功能" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  【PhotoRec - 檔案資料恢復】" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [5] 恢復已刪除的檔案 (PhotoRec CLI)" -ForegroundColor Yellow
    Write-Host "      - 使用命令列介面恢復檔案" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [6] 恢復已刪除的檔案 (QPhotoRec GUI)" -ForegroundColor Yellow
    Write-Host "      - 使用圖形介面恢復檔案（更易用）" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [B] 返回上一級" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "[重要提示]" -ForegroundColor Yellow
    Write-Host "  - TestDisk 和 PhotoRec 是專業工具，建議先閱讀官方文檔" -ForegroundColor Gray
    Write-Host "  - 恢復操作不會修改原始磁碟，但請謹慎操作" -ForegroundColor Gray
    Write-Host "  - 建議將恢復的檔案儲存到不同的磁碟" -ForegroundColor Gray
    Write-Host "  - 官方文檔：https://www.cgsecurity.org/wiki/TestDisk" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "請選擇功能 (1-6, B)"
    return $choice
}

# 執行 TestDisk
function Invoke-TestDisk {
    param([string]$Mode = "advanced")
    
    if (-not (Test-TestDiskInstalled)) {
        if (-not (Install-TestDisk)) {
            return
        }
    }
    
    Write-Host "`n[資訊] 啟動 TestDisk..." -ForegroundColor Cyan
    
    # 檢查是否在安全模式
    $safeMode = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Option" -ErrorAction SilentlyContinue).OptionValue
    if ($safeMode -eq 1 -or $safeMode -eq 2) {
        Write-Host "[資訊] 檢測到安全模式環境（推薦）" -ForegroundColor Green
    }
    
    try {
        switch ($Mode) {
            "recover_partition" {
                Write-Host "[資訊] 啟動分區恢復模式..." -ForegroundColor Cyan
                Write-Host ""
                Write-Host "【操作步驟】" -ForegroundColor Yellow
                Write-Host "  1. 選擇要掃描的磁碟" -ForegroundColor Gray
                Write-Host "  2. 選擇分區表類型（通常選 Intel/PC）" -ForegroundColor Gray
                Write-Host "  3. 選擇 'Analyse' 開始分析" -ForegroundColor Gray
                Write-Host "  4. 選擇 'Quick Search' 快速搜尋丟失的分區" -ForegroundColor Gray
                Write-Host "  5. 如果找到分區，選擇並寫入分區表" -ForegroundColor Gray
                Write-Host ""
                Read-Host "按 Enter 繼續..."
                Start-Process -FilePath $TestDiskExe -Wait -NoNewWindow
            }
            "repair_boot" {
                Write-Host "[資訊] 啟動引導扇區修復模式..." -ForegroundColor Cyan
                Write-Host ""
                Write-Host "【操作步驟】" -ForegroundColor Yellow
                Write-Host "  1. 選擇要修復的磁碟" -ForegroundColor Gray
                Write-Host "  2. 選擇分區表類型" -ForegroundColor Gray
                Write-Host "  3. 選擇 'Advanced' → 選擇分區" -ForegroundColor Gray
                Write-Host "  4. 選擇 'Boot' 查看引導扇區" -ForegroundColor Gray
                Write-Host "  5. 選擇 'Rebuild BS' 重建引導扇區" -ForegroundColor Gray
                Write-Host ""
                Read-Host "按 Enter 繼續..."
                Start-Process -FilePath $TestDiskExe -Wait -NoNewWindow
            }
            "repair_table" {
                Write-Host "[資訊] 啟動分區表修復模式..." -ForegroundColor Cyan
                Write-Host ""
                Write-Host "【操作步驟】" -ForegroundColor Yellow
                Write-Host "  1. 選擇磁碟" -ForegroundColor Gray
                Write-Host "  2. 選擇 'Analyse' → 'Quick Search'" -ForegroundColor Gray
                Write-Host "  3. 檢查找到的分區是否正確" -ForegroundColor Gray
                Write-Host "  4. 選擇 'Write' 寫入新的分區表" -ForegroundColor Gray
                Write-Host ""
                Read-Host "按 Enter 繼續..."
                Start-Process -FilePath $TestDiskExe -Wait -NoNewWindow
            }
            "advanced" {
                Write-Host "[資訊] 啟動 TestDisk 進階模式..." -ForegroundColor Cyan
                Start-Process -FilePath $TestDiskExe -Wait -NoNewWindow
            }
            "photorec_cli" {
                Write-Host "[資訊] 啟動 PhotoRec 命令列模式..." -ForegroundColor Cyan
                Write-Host ""
                Write-Host "【操作步驟】" -ForegroundColor Yellow
                Write-Host "  1. 選擇要掃描的磁碟或分區" -ForegroundColor Gray
                Write-Host "  2. 選擇檔案系統類型" -ForegroundColor Gray
                Write-Host "  3. 選擇掃描範圍（整個分區或僅未分配空間）" -ForegroundColor Gray
                Write-Host "  4. 選擇恢復檔案的儲存位置" -ForegroundColor Gray
                Write-Host "  5. 等待掃描完成" -ForegroundColor Gray
                Write-Host ""
                Read-Host "按 Enter 繼續..."
                Start-Process -FilePath $PhotoRecExe -Wait -NoNewWindow
            }
            "photorec_gui" {
                Write-Host "[資訊] 啟動 QPhotoRec 圖形介面模式..." -ForegroundColor Cyan
                if (Test-Path $QPhotoRecExe) {
                    Start-Process -FilePath $QPhotoRecExe -Wait
                }
                else {
                    Write-Host "[警告] QPhotoRec 不可用，啟動 PhotoRec CLI 模式" -ForegroundColor Yellow
                    Start-Process -FilePath $PhotoRecExe -Wait -NoNewWindow
                }
            }
            default {
                Start-Process -FilePath $TestDiskExe -Wait -NoNewWindow
            }
        }
        
        Write-Host "`n[完成] TestDisk 執行完成" -ForegroundColor Green
    }
    catch {
        Write-Host "`n[錯誤] 執行失敗：$($_.Exception.Message)" -ForegroundColor Red
    }
}

# 主邏輯
Show-ToolInfo

if (-not (Install-TestDisk)) {
    Write-Host "[錯誤] 無法安裝 TestDisk" -ForegroundColor Red
    exit 1
}

if ($CLI) {
    # 命令列模式
    if ($Action) {
        Invoke-TestDisk -Mode $Action
    }
    else {
        Invoke-TestDisk -Mode "advanced"
    }
}
else {
    # 交互式選單模式
    do {
        $choice = Show-Menu
        
        switch ($choice) {
            "1" { Invoke-TestDisk -Mode "recover_partition" }
            "2" { Invoke-TestDisk -Mode "repair_boot" }
            "3" { Invoke-TestDisk -Mode "repair_table" }
            "4" { Invoke-TestDisk -Mode "advanced" }
            "5" { Invoke-TestDisk -Mode "photorec_cli" }
            "6" { Invoke-TestDisk -Mode "photorec_gui" }
            "B" { break }
            "b" { break }
            default {
                Write-Host "[錯誤] 無效的選擇" -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } while ($choice -ne "B" -and $choice -ne "b")
}

Write-Host "`n[資訊] 如果 TestDisk 對您有幫助，請考慮：" -ForegroundColor Cyan
Write-Host "  - 在 GitHub 上給專案一個 ⭐ Star" -ForegroundColor Gray
Write-Host "  - GitHub：$($ToolInfo.GitHub)" -ForegroundColor Gray
Write-Host "  - 官方網站：$($ToolInfo.Website)" -ForegroundColor Gray
Write-Host ""
