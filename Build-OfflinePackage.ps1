# ============================================================================
# Build-OfflinePackage.ps1 - 離線資源打包腳本
# 
# 功能：
# - 自動下載所有離線資源
# - 打包成兩個版本（核心版 + 完整版）
# - 生成 SHA256 校驗碼
# - 創建 Release Notes
# ============================================================================

param(
    [ValidateSet("Core", "Full", "Both")]
    [string]$PackageType = "Both",
    
    [string]$OutputDir = "$PSScriptRoot\Releases",
    
    [switch]$SkipDownload
)

# 設定 UTF-8 編碼
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║              SafeModeDefender 離線資源打包工具                           ║
╚══════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# 創建輸出目錄
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# 版本資訊
$Version = "v2.1"
$BuildDate = Get-Date -Format "yyyy-MM-dd"

# 下載離線資源
if (-not $SkipDownload) {
    Write-Host "[步驟 1/4] 下載離線資源..." -ForegroundColor Cyan
    Write-Host ""
    
    # 執行離線資源管理器
    & "$PSScriptRoot\Core\Offline_Resources_Manager.ps1" -Update -Force -CLI
    
    Write-Host ""
}
else {
    Write-Host "[步驟 1/4] 跳過下載（使用現有資源）" -ForegroundColor Yellow
    Write-Host ""
}

# 定義打包內容
$CoreFiles = @(
    "SafeModeDefender.bat",
    "README.md",
    "EXTERNAL_TOOLS_PLAN.md",
    "OFFLINE_DEPLOYMENT_ANALYSIS.md",
    "PROTECTION_MATRIX.md",
    "Core\*.ps1",
    "Core\Tool_Wrappers\*.ps1",
    "Core\NetworkSecurity\*.ps1",
    "Core\PrivilegeEscalation\*.ps1",
    "Core\RegistryPersistence\*.ps1",
    "Core\FileSystem\*.ps1",
    "Core\MemoryProtection\*.ps1",
    "Core\Privacy\*.ps1",
    "Core\SystemIntegrity\*.ps1",
    "Core\Environment\*.ps1",
    "Core\Firewall\*.ps1",
    "Configs\*.json",
    "Tools\Optimizer\*",
    "Tools\TestDisk\*",
    "Tools\simplewall\*",
    "Tools\PrivescCheck\*",
    "Tools\WinUtil\*"
)

$FullFiles = @(
    "Tools\ClamAV\*"
)

# 打包核心版本
if ($PackageType -eq "Core" -or $PackageType -eq "Both") {
    Write-Host "[步驟 2/4] 打包核心版本..." -ForegroundColor Cyan
    
    $corePackageName = "SafeModeDefender_${Version}_Core.zip"
    $corePackagePath = Join-Path $OutputDir $corePackageName
    
    # 創建臨時目錄
    $tempDir = Join-Path $env:TEMP "SafeModeDefender_Core_Temp"
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    # 複製檔案
    foreach ($pattern in $CoreFiles) {
        $sourcePath = Join-Path $PSScriptRoot $pattern
        
        # 處理萬用字元
        if ($pattern -like "*\*") {
            $parentDir = Split-Path $pattern -Parent
            $destDir = Join-Path $tempDir $parentDir
            
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            $files = Get-Item $sourcePath -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                Copy-Item $file.FullName -Destination $destDir -Force
            }
        }
        else {
            $destPath = Join-Path $tempDir $pattern
            $destDir = Split-Path $destPath -Parent
            
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            if (Test-Path $sourcePath) {
                Copy-Item $sourcePath -Destination $destPath -Force
            }
        }
    }
    
    # 創建 README
    $coreReadme = @"
SafeModeDefender ${Version} - 核心版本

此版本包含：
- 所有內建模塊（33 個）
- 完全離線可用的工具（Optimizer, TestDisk, simplewall, PrivescCheck）
- WinUtil 腳本（部分功能需要網路）

不包含：
- ClamAV 病毒資料庫（需要另外下載或使用完整版）

檔案大小：約 10 MB

適用場景：
- 快速部署
- 檔案大小受限的環境
- 不需要病毒掃描功能

如需 ClamAV 病毒掃描功能，請下載完整版本。

建置日期：${BuildDate}
"@
    
    Set-Content -Path (Join-Path $tempDir "VERSION_INFO.txt") -Value $coreReadme -Encoding UTF8
    
    # 壓縮
    Compress-Archive -Path "$tempDir\*" -DestinationPath $corePackagePath -Force
    
    # 計算 SHA256
    $coreHash = (Get-FileHash -Path $corePackagePath -Algorithm SHA256).Hash
    $coreSize = [math]::Round((Get-Item $corePackagePath).Length / 1MB, 2)
    
    Write-Host "  ✓ 核心版本打包完成" -ForegroundColor Green
    Write-Host "    檔案：$corePackageName" -ForegroundColor Gray
    Write-Host "    大小：$coreSize MB" -ForegroundColor Gray
    Write-Host "    SHA256：$coreHash" -ForegroundColor Gray
    Write-Host ""
    
    # 清理
    Remove-Item $tempDir -Recurse -Force
}

# 打包完整版本
if ($PackageType -eq "Full" -or $PackageType -eq "Both") {
    Write-Host "[步驟 3/4] 打包完整版本..." -ForegroundColor Cyan
    
    $fullPackageName = "SafeModeDefender_${Version}_Full.zip"
    $fullPackagePath = Join-Path $OutputDir $fullPackageName
    
    # 創建臨時目錄
    $tempDir = Join-Path $env:TEMP "SafeModeDefender_Full_Temp"
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    # 複製核心檔案
    foreach ($pattern in $CoreFiles) {
        $sourcePath = Join-Path $PSScriptRoot $pattern
        
        if ($pattern -like "*\*") {
            $parentDir = Split-Path $pattern -Parent
            $destDir = Join-Path $tempDir $parentDir
            
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            $files = Get-Item $sourcePath -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                Copy-Item $file.FullName -Destination $destDir -Force
            }
        }
        else {
            $destPath = Join-Path $tempDir $pattern
            $destDir = Split-Path $destPath -Parent
            
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            if (Test-Path $sourcePath) {
                Copy-Item $sourcePath -Destination $destPath -Force
            }
        }
    }
    
    # 複製完整版檔案（ClamAV）
    foreach ($pattern in $FullFiles) {
        $sourcePath = Join-Path $PSScriptRoot $pattern
        
        if ($pattern -like "*\*") {
            $parentDir = Split-Path $pattern -Parent
            $destDir = Join-Path $tempDir $parentDir
            
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            $files = Get-Item $sourcePath -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                Copy-Item $file.FullName -Destination $destDir -Force -Recurse
            }
        }
    }
    
    # 創建 README
    $fullReadme = @"
SafeModeDefender ${Version} - 完整版本

此版本包含：
- 所有內建模塊（33 個）
- 所有外部工具（WinUtil, Optimizer, TestDisk, simplewall, PrivescCheck）
- ClamAV 病毒資料庫（main.cvd + daily.cvd + bytecode.cvd）

檔案大小：約 250 MB

適用場景：
- 完全離線環境
- 需要病毒掃描功能
- 企業隔離環境
- 緊急修復場景

病毒資料庫日期：${BuildDate}

注意：
- 病毒資料庫會隨時間逐漸過時
- 建議每月更新一次
- 可使用 Offline_Resources_Manager.ps1 更新資料庫

建置日期：${BuildDate}
"@
    
    Set-Content -Path (Join-Path $tempDir "VERSION_INFO.txt") -Value $fullReadme -Encoding UTF8
    
    # 壓縮
    Compress-Archive -Path "$tempDir\*" -DestinationPath $fullPackagePath -Force
    
    # 計算 SHA256
    $fullHash = (Get-FileHash -Path $fullPackagePath -Algorithm SHA256).Hash
    $fullSize = [math]::Round((Get-Item $fullPackagePath).Length / 1MB, 2)
    
    Write-Host "  ✓ 完整版本打包完成" -ForegroundColor Green
    Write-Host "    檔案：$fullPackageName" -ForegroundColor Gray
    Write-Host "    大小：$fullSize MB" -ForegroundColor Gray
    Write-Host "    SHA256：$fullHash" -ForegroundColor Gray
    Write-Host ""
    
    # 清理
    Remove-Item $tempDir -Recurse -Force
}

# 生成校驗碼檔案
Write-Host "[步驟 4/4] 生成校驗碼檔案..." -ForegroundColor Cyan

$checksumContent = @"
SafeModeDefender ${Version} - SHA256 校驗碼

建置日期：${BuildDate}

"@

if ($PackageType -eq "Core" -or $PackageType -eq "Both") {
    $checksumContent += @"

核心版本：
檔案名稱：$corePackageName
檔案大小：$coreSize MB
SHA256：$coreHash

"@
}

if ($PackageType -eq "Full" -or $PackageType -eq "Both") {
    $checksumContent += @"

完整版本：
檔案名稱：$fullPackageName
檔案大小：$fullSize MB
SHA256：$fullHash

"@
}

$checksumContent += @"

驗證方法：
PowerShell:
  Get-FileHash -Path <檔案路徑> -Algorithm SHA256

Linux/macOS:
  shasum -a 256 <檔案路徑>

"@

$checksumPath = Join-Path $OutputDir "SHA256SUMS_${Version}.txt"
Set-Content -Path $checksumPath -Value $checksumContent -Encoding UTF8

Write-Host "  ✓ 校驗碼檔案已生成：SHA256SUMS_${Version}.txt" -ForegroundColor Green
Write-Host ""

# 完成
Write-Host "══════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "打包完成！" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "輸出目錄：$OutputDir" -ForegroundColor Cyan
Write-Host ""

# 列出所有檔案
Get-ChildItem -Path $OutputDir | ForEach-Object {
    $size = [math]::Round($_.Length / 1MB, 2)
    Write-Host "  $($_.Name) ($size MB)" -ForegroundColor Gray
}

Write-Host ""
