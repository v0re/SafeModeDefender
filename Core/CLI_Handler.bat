<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>
# ============================================================================
# CLI_Handler.ps1 - 命令列參數處理模塊（v2.1）
# 
# 功能：解析命令列參數並執行相應的操作
# 支援：靜默模式、批次執行、自動化腳本
# ============================================================================

param(
    [string]$Action = "",
    [string]$Category = "",
    [string]$Module = "",
    [string]$Tool = "",
    [string]$ConfigFile = "",
    [switch]$Silent,
    [switch]$AutoFix,
    [switch]$Help
)

# 設定 UTF-8 編碼
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 顯示幫助資訊
function Show-Help {
    Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║              SafeModeDefender v2.1 - 命令列模式說明                      ║
╚══════════════════════════════════════════════════════════════════════════╝

用法：
  SafeModeDefender.bat [選項]

選項：
  --cli                    啟用命令列模式
  --action <動作>          指定要執行的動作
  --category <類別>        指定要掃描的類別（A-I）
  --module <模塊>          指定要執行的模塊名稱
  --tool <工具>            指定要使用的外部工具
  --config <檔案>          使用配置檔執行批次任務
  --silent                 靜默模式（不顯示互動提示）
  --autofix                自動修復發現的問題（不詢問確認）
  --help                   顯示此幫助資訊

動作類型：
  scan                     執行掃描
  fix                      執行修復
  report                   生成報告
  full                     執行完整掃描（所有模塊）

類別代碼：
  A - 網路服務與端口安全（7 個模塊）
  B - 系統權限與提權防護（5 個模塊）
  C - 註冊表與持久化防護（4 個模塊）
  D - 檔案系統與隱藏威脅（4 個模塊）
  E - 記憶體與漏洞防護（3 個模塊）
  F - 隱私權與遙測（2 個模塊）
  G - 系統完整性與更新（3 個模塊）
  H - 環境變數與 Hosts（2 個模塊）
  I - 防火牆與策略（3 個模塊）

外部工具：
  winutil                  Chris Titus Tech's Windows Utility
  optimizer                Optimizer 隱私和安全增強工具
  testdisk                 TestDisk & PhotoRec 資料救援工具
  clamav                   ClamAV 防毒引擎
  simplewall               simplewall 防火牆管理工具
  privesccheck             PrivescCheck 權限提升檢測工具

範例：
  # 執行完整掃描
  SafeModeDefender.bat --cli --action full

  # 掃描網路安全類別
  SafeModeDefender.bat --cli --action scan --category A

  # 執行特定模塊
  SafeModeDefender.bat --cli --action scan --module A1_SMB_Security

  # 靜默模式自動修復
  SafeModeDefender.bat --cli --action fix --category A --silent --autofix

  # 使用外部工具
  SafeModeDefender.bat --cli --tool testdisk --action recover_partition

  # 使用配置檔批次執行
  SafeModeDefender.bat --cli --config scan_config.json

配置檔格式（JSON）：
  {
    "tasks": [
      {
        "type": "scan",
        "category": "A"
      },
      {
        "type": "tool",
        "tool": "optimizer",
        "action": "privacy"
      }
    ]
  }

══════════════════════════════════════════════════════════════════════════

"@
}

# 模塊對應表
$ModuleMapping = @{
    # 網路安全 (A)
    "A1_SMB_Security" = "NetworkSecurity\A1_SMB_Security.ps1"
    "A2_RDP_Security" = "NetworkSecurity\A2_RDP_Security.ps1"
    "A3_UPnP_Disable" = "NetworkSecurity\A3_UPnP_Disable.ps1"
    "A4_mDNS_Disable" = "NetworkSecurity\A4_mDNS_Disable.ps1"
    "A5_WinRM_Security" = "NetworkSecurity\A5_WinRM_Security.ps1"
    "A6_LLMNR_Disable" = "NetworkSecurity\A6_LLMNR_Disable.ps1"
    "A7_Port_Scanner" = "NetworkSecurity\A7_Port_Scanner.ps1"
    
    # 權限與提權 (B)
    "B1_UAC_Hardening" = "PrivilegeEscalation\B1_UAC_Hardening.ps1"
    "B2_Admin_Account_Check" = "PrivilegeEscalation\B2_Admin_Account_Check.ps1"
    "B3_Scheduled_Tasks_Audit" = "PrivilegeEscalation\B3_Scheduled_Tasks_Audit.ps1"
    "B4_Service_Permissions" = "PrivilegeEscalation\B4_Service_Permissions.ps1"
    "B5_DLL_Hijacking_Prevention" = "PrivilegeEscalation\B5_DLL_Hijacking_Prevention.ps1"
    
    # 註冊表 (C)
    "C1_Autorun_Registry_Scan" = "RegistryPersistence\C1_Autorun_Registry_Scan.ps1"
    "C2_WMI_Persistence_Check" = "RegistryPersistence\C2_WMI_Persistence_Check.ps1"
    "C3_Browser_Extension_Audit" = "RegistryPersistence\C3_Browser_Extension_Audit.ps1"
    "C4_Startup_Folder_Monitor" = "RegistryPersistence\C4_Startup_Folder_Monitor.ps1"
    
    # 檔案系統 (D)
    "D1_Hidden_Files_Scan" = "FileSystem\D1_Hidden_Files_Scan.ps1"
    "D2_ADS_Detection" = "FileSystem\D2_ADS_Detection.ps1"
    "D3_System_File_Integrity" = "FileSystem\D3_System_File_Integrity.ps1"
    "D4_Suspicious_Executables" = "FileSystem\D4_Suspicious_Executables.ps1"
    
    # 記憶體與漏洞 (E)
    "E1_DEP_ASLR_Check" = "MemoryProtection\E1_DEP_ASLR_Check.ps1"
    "E2_Patch_Status_Audit" = "MemoryProtection\E2_Patch_Status_Audit.ps1"
    "E3_Memory_Protection" = "MemoryProtection\E3_Memory_Protection.ps1"
    
    # 隱私 (F)
    "F1_Telemetry_Disable" = "Privacy\F1_Telemetry_Disable.ps1"
    "F2_Privacy_Settings" = "Privacy\F2_Privacy_Settings.ps1"
    
    # 系統完整性 (G)
    "G1_System_File_Checker" = "SystemIntegrity\G1_System_File_Checker.ps1"
    "G2_Component_Store_Health" = "SystemIntegrity\G2_Component_Store_Health.ps1"
    "G3_BIOS_Update_Detection" = "SystemIntegrity\G3_BIOS_Update_Detection.ps1"
    
    # 環境變數 (H)
    "H1_Environment_Variables_Scan" = "Environment\H1_Environment_Variables_Scan.ps1"
    "H2_Hosts_File_Monitor" = "Environment\H2_Hosts_File_Monitor.ps1"
    
    # 防火牆 (I)
    "I1_Firewall_Rules_Audit" = "Firewall\I1_Firewall_Rules_Audit.ps1"
    "I2_Windows_Firewall_Hardening" = "Firewall\I2_Windows_Firewall_Hardening.ps1"
    "I3_Network_Profile_Security" = "Firewall\I3_Network_Profile_Security.ps1",
    "I1_AnyDesk_Security" = "AnyDesk\I1_AnyDesk_Security.ps1"
}

# 類別對應表
$CategoryMapping = @{
    "A" = @("A1_SMB_Security", "A2_RDP_Security", "A3_UPnP_Disable", "A4_mDNS_Disable", "A5_WinRM_Security", "A6_LLMNR_Disable", "A7_Port_Scanner")
    "B" = @("B1_UAC_Hardening", "B2_Admin_Account_Check", "B3_Scheduled_Tasks_Audit", "B4_Service_Permissions", "B5_DLL_Hijacking_Prevention")
    "C" = @("C1_Autorun_Registry_Scan", "C2_WMI_Persistence_Check", "C3_Browser_Extension_Audit", "C4_Startup_Folder_Monitor")
    "D" = @("D1_Hidden_Files_Scan", "D2_ADS_Detection", "D3_System_File_Integrity", "D4_Suspicious_Executables")
    "E" = @("E1_DEP_ASLR_Check", "E2_Patch_Status_Audit", "E3_Memory_Protection")
    "F" = @("F1_Telemetry_Disable", "F2_Privacy_Settings")
    "G" = @("G1_System_File_Checker", "G2_Component_Store_Health", "G3_BIOS_Update_Detection")
    "H" = @("H1_Environment_Variables_Scan", "H2_Hosts_File_Monitor")
    "I" = @("I1_Firewall_Rules_Audit", "I2_Windows_Firewall_Hardening", "I3_Network_Profile_Security", "I1_AnyDesk_Security")
}

# 執行模塊
function Invoke-Module {
    param([string]$ModuleName)
    
    if (-not $ModuleMapping.ContainsKey($ModuleName)) {
        Write-Host "[錯誤] 未知的模塊：$ModuleName" -ForegroundColor Red
        return $false
    }
    
    # 使用安全的路徑處理
    $coreDir = Split-Path -Parent $PSScriptRoot
    $modulePath = Join-Path $coreDir $ModuleMapping[$ModuleName]
    
    # 驗證檔案存在
    if (-not (Test-Path $modulePath)) {
        Write-Host "`n[錯誤] 模塊檔案不存在：$modulePath" -ForegroundColor Red
        Write-Host "[原因] 此模塊可能尚未開發完成或檔案被移動" -ForegroundColor Yellow
        Write-Host "[建議] 請執行以下檢查：" -ForegroundColor Cyan
        Write-Host "  1. 確認 SafeModeDefender 安裝完整：git pull" -ForegroundColor Gray
        Write-Host "  2. 檢查檔案是否存在：Test-Path '$modulePath'" -ForegroundColor Gray
        Write-Host "  3. 查看可用模塊清單：Get-ChildItem '$coreDir' -Filter '*.ps1'`n" -ForegroundColor Gray
        return $false
    }
    
    Write-Host "[執行] $ModuleName" -ForegroundColor Cyan
    
    try {
        & powershell.exe -ExecutionPolicy Bypass -File $modulePath
        Write-Host "[完成] $ModuleName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[錯誤] $ModuleName 執行失敗：$($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 執行類別
function Invoke-Category {
    param([string]$CategoryCode)
    
    if (-not $CategoryMapping.ContainsKey($CategoryCode.ToUpper())) {
        Write-Host "[錯誤] 無效的類別：$CategoryCode" -ForegroundColor Red
        return $false
    }
    
    $modules = $CategoryMapping[$CategoryCode.ToUpper()]
    $successCount = 0
    $failCount = 0
    
    Write-Host "`n══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "執行類別 $CategoryCode （共 $($modules.Count) 個模塊）" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
    
    foreach ($module in $modules) {
        if (Invoke-Module -ModuleName $module) {
            $successCount++
        }
        else {
            $failCount++
        }
        Write-Host ""
    }
    
    Write-Host "══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "類別 $CategoryCode 執行完成：成功 $successCount 個，失敗 $failCount 個" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "══════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
    
    return ($failCount -eq 0)
}

# 主處理邏輯
if ($Help) {
    Show-Help
    exit 0
}

# 驗證參數
if (-not $Action -and -not $ConfigFile) {
    Write-Host "[錯誤] 必須指定 --action 或 --config 參數" -ForegroundColor Red
    Write-Host "使用 --help 查看完整說明" -ForegroundColor Yellow
    exit 1
}

# 處理配置檔模式
if ($ConfigFile) {
    if (-not (Test-Path $ConfigFile)) {
        Write-Host "[錯誤] 配置檔不存在：$ConfigFile" -ForegroundColor Red
        exit 1
    }
    
    try {
        $config = Get-Content $ConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        
        # 驗證配置檔結構
        if (-not $config.tasks) {
            Write-Host "[錯誤] 配置檔格式錯誤：缺少 'tasks' 字段" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "[資訊] 載入配置檔：$ConfigFile" -ForegroundColor Cyan
        Write-Host "[資訊] 共 $($config.tasks.Count) 個任務" -ForegroundColor Cyan
        
        $taskIndex = 0
        foreach ($task in $config.tasks) {
            $taskIndex++
            Write-Host "`n執行任務：$($task.type)" -ForegroundColor Green
            
            switch ($task.type) {
                "scan" {
                    try {
                        if ($task.category) {
                            Invoke-Category -CategoryCode $task.category
                        }
                        elseif ($task.module) {
                            Invoke-Module -ModuleName $task.module
                        }
                        else {
                            Write-Host "[警告] 任務 $taskIndex 缺少 category 或 module 參數" -ForegroundColor Yellow
                        }
                    }
                    catch {
                        Write-Host "[錯誤] 任務 $taskIndex 執行失敗：$($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                "tool" {
                    if ($task.tool) {
                        $toolManagerPath = Join-Path $PSScriptRoot "External_Tools_Manager.ps1"
                        & powershell.exe -ExecutionPolicy Bypass -File $toolManagerPath -Tool $task.tool -Action $task.action -CLI -Silent
                    }
                }
            }
        }
    }
    catch {
        Write-Host "[錯誤] 配置檔格式錯誤：$($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
    exit 0
}

# 處理單一動作模式
switch ($Action.ToLower()) {
    "scan" {
        if ($Module) {
            Write-Host "[資訊] 掃描模塊：$Module" -ForegroundColor Cyan
            Invoke-Module -ModuleName $Module
        }
        elseif ($Category) {
            Write-Host "[資訊] 掃描類別：$Category" -ForegroundColor Cyan
            Invoke-Category -CategoryCode $Category
        }
        else {
            Write-Host "[錯誤] 必須指定 --module 或 --category" -ForegroundColor Red
            exit 1
        }
    }
    
    "fix" {
        Write-Host "[資訊] 修復模式與掃描模式相同，模塊內會提供修復選項" -ForegroundColor Yellow
        
        if ($Module) {
            Invoke-Module -ModuleName $Module
        }
        elseif ($Category) {
            Invoke-Category -CategoryCode $Category
        }
        else {
            Write-Host "[錯誤] 必須指定 --module 或 --category" -ForegroundColor Red
            exit 1
        }
    }
    
    "full" {
        Write-Host "[資訊] 執行完整掃描（所有 33 個模塊）" -ForegroundColor Cyan
        
        $totalSuccess = 0
        $totalFail = 0
        
        foreach ($cat in $CategoryMapping.Keys | Sort-Object) {
            $result = Invoke-Category -CategoryCode $cat
            # 統計結果（簡化版）
        }
        
        Write-Host "`n══════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host "完整掃描完成！" -ForegroundColor Green
        Write-Host "══════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Green
    }
    
    "report" {
        Write-Host "[資訊] 生成報告" -ForegroundColor Cyan
        
        $reportsDir = "$PSScriptRoot\..\Reports"
        if (Test-Path $reportsDir) {
            $reports = Get-ChildItem -Path $reportsDir -Filter "*.html" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
            
            if ($reports -and $reports.Count -gt 0) {
                Write-Host "`n可用的報告：" -ForegroundColor Cyan
                foreach ($report in $reports) {
                    Write-Host "  - $($report.Name) ($($report.LastWriteTime))" -ForegroundColor Gray
                }
                
                Write-Host "`n報告目錄：$reportsDir" -ForegroundColor Cyan
            }
            else {
                Write-Host "[資訊] 尚無可用的報告" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "[資訊] 報告目錄不存在" -ForegroundColor Yellow
        }
    }
    
    default {
        Write-Host "[錯誤] 無效的動作：$Action" -ForegroundColor Red
        Write-Host "有效的動作：scan, fix, full, report" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "`n[完成] 命令列操作已完成" -ForegroundColor Green
exit 0
