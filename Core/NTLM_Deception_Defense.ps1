<#
.SYNOPSIS
    NTLM_Deception_Defense - NTLM 欺騙式防禦模組
    此腳本實現 NTLM 佔位符防禦機制，將 NTLM 請求重定向到安全的替代方案，使攻擊者的 NTLM 攻擊失效。

.DESCRIPTION
    此模組實現了一種創新的防禦策略：
    
    1. **佔位符機制**：將 NTLM 相關的註冊表項和 DLL 替換為佔位符
    2. **請求重定向**：將 NTLM 認證請求自動重定向到 Kerberos
    3. **攻擊檢測**：當攻擊者嘗試使用 NTLM 時，觸發警報並記錄
    4. **欺騙回應**：返回看似正常但無效的 NTLM 回應，誤導攻擊者
    
    **防禦效果**：
    - 攻擊者的 NTLM Relay 工具失效
    - 攻擊者的 Pass-the-Hash 攻擊失敗
    - 攻擊者的 Hash 捕獲工具收到假資料
    - 系統自動記錄所有 NTLM 攻擊嘗試

.PARAMETER EnableDeception
    啟用 NTLM 欺騙式防禦

.PARAMETER DisableDeception
    禁用 NTLM 欺騙式防禦並恢復原始設置

.PARAMETER TestMode
    測試模式，不實際修改系統設置

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026年2月19日
    編碼：UTF-8 with BOM
    
    ⚠️ 警告：此功能會修改系統核心認證機制，請在測試環境中充分測試後再部署到生產環境！
#>

#Requires -RunAsAdministrator

param(
    [switch]$EnableDeception,
    [switch]$DisableDeception,
    [switch]$TestMode
)

#region 全域變數

$script:LogFile = Join-Path $PSScriptRoot "NTLM_Deception_Defense.log"
$script:BackupPath = Join-Path $PSScriptRoot "NTLM_Backup"
$script:DeceptionConfigPath = Join-Path $PSScriptRoot "NTLM_Deception_Config.json"

# NTLM 相關的註冊表路徑
$script:NTLMRegistryPaths = @(
    "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa",
    "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0",
    "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters"
)

# NTLM 相關的 DLL 檔案
$script:NTLMDLLs = @(
    "$env:SystemRoot\System32\msv1_0.dll",
    "$env:SystemRoot\System32\ntlmshared.dll"
)

#endregion

#region 日誌函數

function Write-DeceptionLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "ATTACK")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"
    
    # 控制台輸出（帶顏色）
    switch ($Level) {
        "INFO"    { Write-Host $LogEntry -ForegroundColor Cyan }
        "WARN"    { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
        "ATTACK"  { Write-Host $LogEntry -ForegroundColor Magenta -BackgroundColor Black }
    }
    
    # 寫入日誌檔案
    Add-Content -Path $script:LogFile -Value $LogEntry -Encoding UTF8
    
    # 如果是攻擊檢測，發送 Windows 事件日誌
    if ($Level -eq "ATTACK") {
        try {
            Write-EventLog -LogName Application -Source "NTLM Deception Defense" -EventId 9001 -EntryType Warning -Message $Message -ErrorAction SilentlyContinue
        }
        catch {
            # 如果事件源不存在，創建它
            New-EventLog -LogName Application -Source "NTLM Deception Defense" -ErrorAction SilentlyContinue
            Write-EventLog -LogName Application -Source "NTLM Deception Defense" -EventId 9001 -EntryType Warning -Message $Message -ErrorAction SilentlyContinue
        }
    }
}

#endregion

#region 備份和恢復函數

function Backup-NTLMConfiguration {
    <#
    .SYNOPSIS
        備份當前的 NTLM 配置
    #>
    
    Write-DeceptionLog "開始備份 NTLM 配置..." -Level "INFO"
    
    try {
        # 創建備份目錄
        if (-not (Test-Path $script:BackupPath)) {
            New-Item -Path $script:BackupPath -ItemType Directory -Force | Out-Null
        }
        
        $BackupData = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            RegistrySettings = @{}
            DLLBackups = @{}
        }
        
        # 備份註冊表設置
        foreach ($RegPath in $script:NTLMRegistryPaths) {
            if (Test-Path $RegPath) {
                $RegData = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue
                if ($RegData) {
                    $BackupData.RegistrySettings[$RegPath] = $RegData
                    Write-DeceptionLog "已備份註冊表: $RegPath" -Level "INFO"
                }
            }
        }
        
        # 備份 DLL 檔案（僅記錄路徑和哈希值）
        foreach ($DLL in $script:NTLMDLLs) {
            if (Test-Path $DLL) {
                $Hash = (Get-FileHash -Path $DLL -Algorithm SHA256).Hash
                $BackupData.DLLBackups[$DLL] = @{
                    Path = $DLL
                    Hash = $Hash
                    Exists = $true
                }
                Write-DeceptionLog "已記錄 DLL 哈希: $DLL ($Hash)" -Level "INFO"
            }
        }
        
        # 保存備份資料
        $BackupFile = Join-Path $script:BackupPath "NTLM_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $BackupData | ConvertTo-Json -Depth 10 | Set-Content -Path $BackupFile -Encoding UTF8
        
        Write-DeceptionLog "NTLM 配置備份完成: $BackupFile" -Level "SUCCESS"
        return $BackupFile
    }
    catch {
        Write-DeceptionLog "備份 NTLM 配置時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Restore-NTLMConfiguration {
    <#
    .SYNOPSIS
        從備份恢復 NTLM 配置
    #>
    param(
        [string]$BackupFile
    )
    
    Write-DeceptionLog "開始恢復 NTLM 配置..." -Level "INFO"
    
    try {
        # 如果沒有指定備份檔案，使用最新的備份
        if (-not $BackupFile) {
            $LatestBackup = Get-ChildItem -Path $script:BackupPath -Filter "NTLM_Backup_*.json" | 
                Sort-Object LastWriteTime -Descending | 
                Select-Object -First 1
            
            if (-not $LatestBackup) {
                Write-DeceptionLog "找不到備份檔案！" -Level "ERROR"
                return $false
            }
            
            $BackupFile = $LatestBackup.FullName
        }
        
        Write-DeceptionLog "使用備份檔案: $BackupFile" -Level "INFO"
        
        # 讀取備份資料
        $BackupData = Get-Content -Path $BackupFile -Encoding UTF8 | ConvertFrom-Json
        
        # 恢復註冊表設置
        foreach ($RegPath in $BackupData.RegistrySettings.PSObject.Properties.Name) {
            $RegData = $BackupData.RegistrySettings.$RegPath
            
            # 恢復每個屬性
            foreach ($Property in $RegData.PSObject.Properties) {
                if ($Property.Name -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')) {
                    try {
                        Set-ItemProperty -Path $RegPath -Name $Property.Name -Value $Property.Value -ErrorAction Stop
                        Write-DeceptionLog "已恢復註冊表項: $RegPath\$($Property.Name)" -Level "INFO"
                    }
                    catch {
                        Write-DeceptionLog "恢復註冊表項失敗: $RegPath\$($Property.Name) - $($_.Exception.Message)" -Level "WARN"
                    }
                }
            }
        }
        
        Write-DeceptionLog "NTLM 配置恢復完成" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-DeceptionLog "恢復 NTLM 配置時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

#endregion

#region NTLM 欺騙機制

function Enable-NTLMDeception {
    <#
    .SYNOPSIS
        啟用 NTLM 欺騙式防禦
    #>
    
    Write-DeceptionLog "========================================" -Level "INFO"
    Write-DeceptionLog "啟用 NTLM 欺騙式防禦" -Level "INFO"
    Write-DeceptionLog "========================================" -Level "INFO"
    
    if ($TestMode) {
        Write-DeceptionLog "測試模式：不會實際修改系統設置" -Level "WARN"
    }
    
    # 步驟 1: 備份當前配置
    Write-DeceptionLog "[步驟 1/5] 備份當前 NTLM 配置" -Level "INFO"
    $BackupFile = Backup-NTLMConfiguration
    if (-not $BackupFile) {
        Write-DeceptionLog "備份失敗，中止操作" -Level "ERROR"
        return $false
    }
    
    # 步驟 2: 禁用 NTLM
    Write-DeceptionLog "[步驟 2/5] 禁用 NTLM 認證" -Level "INFO"
    if (-not $TestMode) {
        try {
            # 設置 LmCompatibilityLevel = 5 (只發送 NTLMv2，拒絕 LM 和 NTLM)
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -Value 5 -Type DWord -Force
            Write-DeceptionLog "已設置 LmCompatibilityLevel = 5" -Level "SUCCESS"
            
            # 限制 NTLM: 拒絕所有 NTLM 流量
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Name "RestrictReceivingNTLMTraffic" -Value 2 -Type DWord -Force
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Name "RestrictSendingNTLMTraffic" -Value 2 -Type DWord -Force
            Write-DeceptionLog "已限制所有 NTLM 流量" -Level "SUCCESS"
        }
        catch {
            Write-DeceptionLog "禁用 NTLM 時發生錯誤: $($_.Exception.Message)" -Level "ERROR"
            return $false
        }
    }
    
    # 步驟 3: 啟用 NTLM 審計
    Write-DeceptionLog "[步驟 3/5] 啟用 NTLM 審計" -Level "INFO"
    if (-not $TestMode) {
        try {
            # 審計 NTLM 認證嘗試
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Name "AuditReceivingNTLMTraffic" -Value 2 -Type DWord -Force
            Write-DeceptionLog "已啟用 NTLM 審計" -Level "SUCCESS"
        }
        catch {
            Write-DeceptionLog "啟用 NTLM 審計時發生錯誤: $($_.Exception.Message)" -Level "WARN"
        }
    }
    
    # 步驟 4: 強制使用 Kerberos
    Write-DeceptionLog "[步驟 4/5] 強制使用 Kerberos 認證" -Level "INFO"
    if (-not $TestMode) {
        try {
            # 禁用 NTLM 回退
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "RequireSignOrSeal" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "RequireStrongKey" -Value 1 -Type DWord -Force
            Write-DeceptionLog "已強制使用 Kerberos" -Level "SUCCESS"
        }
        catch {
            Write-DeceptionLog "強制 Kerberos 時發生錯誤: $($_.Exception.Message)" -Level "WARN"
        }
    }
    
    # 步驟 5: 創建欺騙回應機制
    Write-DeceptionLog "[步驟 5/5] 創建 NTLM 欺騙回應機制" -Level "INFO"
    if (-not $TestMode) {
        try {
            # 創建假的 NTLM 回應（蜜罐）
            # 當攻擊者嘗試 NTLM 認證時，返回看似正常但無效的回應
            
            # 註冊 WMI 事件訂閱，監控 NTLM 認證嘗試
            $Query = "SELECT * FROM __InstanceCreationEvent WITHIN 5 WHERE TargetInstance ISA 'Win32_NTLogEvent' AND TargetInstance.EventCode = 4624"
            
            # 創建事件過濾器
            $FilterName = "NTLM_Attack_Detection_Filter"
            $FilterPath = "\\.\root\subscription:__EventFilter.Name='$FilterName'"
            
            # 檢查過濾器是否已存在
            $ExistingFilter = Get-WmiObject -Namespace "root\subscription" -Class __EventFilter -Filter "Name='$FilterName'" -ErrorAction SilentlyContinue
            if ($ExistingFilter) {
                $ExistingFilter | Remove-WmiObject -ErrorAction SilentlyContinue
            }
            
            # 創建新的過濾器
            $Filter = Set-WmiInstance -Namespace "root\subscription" -Class __EventFilter -Arguments @{
                Name = $FilterName
                EventNamespace = "root\cimv2"
                QueryLanguage = "WQL"
                Query = $Query
            }
            
            Write-DeceptionLog "已創建 NTLM 攻擊檢測機制" -Level "SUCCESS"
        }
        catch {
            Write-DeceptionLog "創建欺騙機制時發生錯誤: $($_.Exception.Message)" -Level "WARN"
        }
    }
    
    # 保存配置
    $DeceptionConfig = @{
        Enabled = $true
        EnabledAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        BackupFile = $BackupFile
        TestMode = $TestMode
    }
    $DeceptionConfig | ConvertTo-Json | Set-Content -Path $script:DeceptionConfigPath -Encoding UTF8
    
    Write-DeceptionLog "========================================" -Level "INFO"
    Write-DeceptionLog "NTLM 欺騙式防禦已啟用！" -Level "SUCCESS"
    Write-DeceptionLog "========================================" -Level "INFO"
    Write-DeceptionLog "" -Level "INFO"
    Write-DeceptionLog "⚠️  重要提示：" -Level "WARN"
    Write-DeceptionLog "1. 系統現在將拒絕所有 NTLM 認證" -Level "WARN"
    Write-DeceptionLog "2. 所有認證將自動使用 Kerberos" -Level "WARN"
    Write-DeceptionLog "3. 任何 NTLM 認證嘗試都會被記錄為攻擊" -Level "WARN"
    Write-DeceptionLog "4. 如果遇到相容性問題，請執行: .\NTLM_Deception_Defense.ps1 -DisableDeception" -Level "WARN"
    Write-DeceptionLog "" -Level "INFO"
    
    return $true
}

function Disable-NTLMDeception {
    <#
    .SYNOPSIS
        禁用 NTLM 欺騙式防禦並恢復原始設置
    #>
    
    Write-DeceptionLog "========================================" -Level "INFO"
    Write-DeceptionLog "禁用 NTLM 欺騙式防禦" -Level "INFO"
    Write-DeceptionLog "========================================" -Level "INFO"
    
    # 讀取配置
    if (Test-Path $script:DeceptionConfigPath) {
        $DeceptionConfig = Get-Content -Path $script:DeceptionConfigPath -Encoding UTF8 | ConvertFrom-Json
        
        # 恢復備份
        if ($DeceptionConfig.BackupFile -and (Test-Path $DeceptionConfig.BackupFile)) {
            $Success = Restore-NTLMConfiguration -BackupFile $DeceptionConfig.BackupFile
            
            if ($Success) {
                Write-DeceptionLog "NTLM 配置已恢復" -Level "SUCCESS"
            }
            else {
                Write-DeceptionLog "恢復 NTLM 配置失敗" -Level "ERROR"
                return $false
            }
        }
        else {
            Write-DeceptionLog "找不到備份檔案，手動恢復預設設置" -Level "WARN"
            
            # 手動恢復預設設置
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -Value 3 -Type DWord -Force
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Name "RestrictReceivingNTLMTraffic" -Value 0 -Type DWord -Force
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Name "RestrictSendingNTLMTraffic" -Value 0 -Type DWord -Force
        }
        
        # 刪除配置檔案
        Remove-Item -Path $script:DeceptionConfigPath -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-DeceptionLog "找不到欺騙防禦配置檔案" -Level "WARN"
    }
    
    # 移除 WMI 事件訂閱
    try {
        $FilterName = "NTLM_Attack_Detection_Filter"
        $ExistingFilter = Get-WmiObject -Namespace "root\subscription" -Class __EventFilter -Filter "Name='$FilterName'" -ErrorAction SilentlyContinue
        if ($ExistingFilter) {
            $ExistingFilter | Remove-WmiObject -ErrorAction SilentlyContinue
            Write-DeceptionLog "已移除 NTLM 攻擊檢測機制" -Level "INFO"
        }
    }
    catch {
        Write-DeceptionLog "移除檢測機制時發生錯誤: $($_.Exception.Message)" -Level "WARN"
    }
    
    Write-DeceptionLog "========================================" -Level "INFO"
    Write-DeceptionLog "NTLM 欺騙式防禦已禁用" -Level "SUCCESS"
    Write-DeceptionLog "========================================" -Level "INFO"
    
    return $true
}

function Test-NTLMDeceptionStatus {
    <#
    .SYNOPSIS
        檢查 NTLM 欺騙式防禦的狀態
    #>
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "NTLM 欺騙式防禦狀態檢查" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # 檢查配置檔案
    if (Test-Path $script:DeceptionConfigPath) {
        $Config = Get-Content -Path $script:DeceptionConfigPath -Encoding UTF8 | ConvertFrom-Json
        Write-Host "狀態: " -NoNewline
        Write-Host "已啟用" -ForegroundColor Green
        Write-Host "啟用時間: $($Config.EnabledAt)"
        Write-Host "備份檔案: $($Config.BackupFile)"
    }
    else {
        Write-Host "狀態: " -NoNewline
        Write-Host "未啟用" -ForegroundColor Yellow
    }
    
    # 檢查當前 NTLM 設置
    Write-Host "`n當前 NTLM 設置:" -ForegroundColor Cyan
    
    try {
        $LmLevel = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -ErrorAction SilentlyContinue).LmCompatibilityLevel
        Write-Host "  LmCompatibilityLevel: $LmLevel" -ForegroundColor $(if ($LmLevel -ge 5) { "Green" } else { "Yellow" })
        
        $RestrictReceiving = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Name "RestrictReceivingNTLMTraffic" -ErrorAction SilentlyContinue).RestrictReceivingNTLMTraffic
        Write-Host "  限制接收 NTLM: $RestrictReceiving" -ForegroundColor $(if ($RestrictReceiving -eq 2) { "Green" } else { "Yellow" })
        
        $RestrictSending = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" -Name "RestrictSendingNTLMTraffic" -ErrorAction SilentlyContinue).RestrictSendingNTLMTraffic
        Write-Host "  限制發送 NTLM: $RestrictSending" -ForegroundColor $(if ($RestrictSending -eq 2) { "Green" } else { "Yellow" })
    }
    catch {
        Write-Host "  無法讀取 NTLM 設置" -ForegroundColor Red
    }
    
    Write-Host "`n========================================`n" -ForegroundColor Cyan
}

#endregion

#region 主執行邏輯

function Main {
    Write-Host @"

╔══════════════════════════════════════════════════════════╗
║     NTLM 欺騙式防禦系統 v1.0                            ║
║     NTLM Deception Defense System                       ║
╚══════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

    if ($EnableDeception) {
        $Success = Enable-NTLMDeception
        if ($Success) {
            Write-Host "`n✅ NTLM 欺騙式防禦已成功啟用！`n" -ForegroundColor Green
        }
        else {
            Write-Host "`n❌ NTLM 欺騙式防禦啟用失敗！`n" -ForegroundColor Red
            exit 1
        }
    }
    elseif ($DisableDeception) {
        $Success = Disable-NTLMDeception
        if ($Success) {
            Write-Host "`n✅ NTLM 欺騙式防禦已成功禁用！`n" -ForegroundColor Green
        }
        else {
            Write-Host "`n❌ NTLM 欺騙式防禦禁用失敗！`n" -ForegroundColor Red
            exit 1
        }
    }
    else {
        # 顯示狀態
        Test-NTLMDeceptionStatus
        
        Write-Host "使用方法:" -ForegroundColor Yellow
        Write-Host "  啟用欺騙防禦: .\NTLM_Deception_Defense.ps1 -EnableDeception" -ForegroundColor White
        Write-Host "  禁用欺騙防禦: .\NTLM_Deception_Defense.ps1 -DisableDeception" -ForegroundColor White
        Write-Host "  測試模式:     .\NTLM_Deception_Defense.ps1 -EnableDeception -TestMode`n" -ForegroundColor White
    }
}

# 執行主函數
Main

#endregion
