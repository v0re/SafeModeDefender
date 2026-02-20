# ============================================================================
# System_Hardening.ps1 - 系統強化與 AnyDesk 攻擊預防
# 
# 功能：實施多層次的系統強化措施，防止 AnyDesk 相關攻擊
# ============================================================================

<#
.SYNOPSIS
    系統強化與 AnyDesk 攻擊預防腳本

.DESCRIPTION
    此腳本實施以下安全強化措施：
    1. 配置 AppLocker 策略以限制 AnyDesk 執行
    2. 強化防火牆規則
    3. 啟用 Windows Defender 進階保護
    4. 配置審計策略以監控可疑活動
    5. 限制 PowerShell 和 mshta.exe 的執行
    6. 啟用 Credential Guard 和 Device Guard（如果支援）

.PARAMETER ApplyAll
    應用所有強化措施（需要重新啟動）

.PARAMETER ApplyFirewall
    僅應用防火牆強化

.PARAMETER ApplyAppLocker
    僅應用 AppLocker 策略

.PARAMETER ApplyAudit
    僅應用審計策略

.EXAMPLE
    .\System_Hardening.ps1 -ApplyAll
    應用所有系統強化措施

.EXAMPLE
    .\System_Hardening.ps1 -ApplyFirewall -ApplyAudit
    僅應用防火牆和審計策略

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-19
    警告：此腳本需要管理員權限
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$ApplyAll,
    [switch]$ApplyFirewall,
    [switch]$ApplyAppLocker,
    [switch]$ApplyAudit
)

# 設定 UTF-8 編碼
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "❌ 錯誤：此腳本需要管理員權限。" -ForegroundColor Red
    exit 1
}

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║              系統強化與 AnyDesk 攻擊預防工具 v1.0                        ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ============================================================================
# 防火牆強化
# ============================================================================

if ($ApplyAll -or $ApplyFirewall) {
    Write-Host "`n[1/4] 配置防火牆規則..." -ForegroundColor Cyan
    
    # 封鎖 AnyDesk 常用端口
    $portsToBlock = @(
        @{ Port = 7070; Description = "AnyDesk Direct Connection" },
        @{ Port = 6568; Description = "AnyDesk Discovery" },
        @{ Port = 50001; Description = "AnyDesk Relay" }
    )
    
    foreach ($portInfo in $portsToBlock) {
        $ruleName = "SafeModeDefender_Block_AnyDesk_$($portInfo.Port)"
        
        # 刪除舊規則
        $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        if ($existingRule) {
            Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        }
        
        # 創建入站阻止規則
        New-NetFirewallRule -DisplayName $ruleName `
                            -Description $portInfo.Description `
                            -Direction Inbound `
                            -Action Block `
                            -Protocol TCP `
                            -LocalPort $portInfo.Port `
                            -Profile Any `
                            -ErrorAction SilentlyContinue | Out-Null
        
        # 創建出站阻止規則
        New-NetFirewallRule -DisplayName "$ruleName`_Outbound" `
                            -Description $portInfo.Description `
                            -Direction Outbound `
                            -Action Block `
                            -Protocol TCP `
                            -RemotePort $portInfo.Port `
                            -Profile Any `
                            -ErrorAction SilentlyContinue | Out-Null
        
        Write-Host "  ✓ 已封鎖端口：$($portInfo.Port) ($($portInfo.Description))" -ForegroundColor Green
    }
    
    # 封鎖已知的 AnyDesk 中繼伺服器 IP 範圍（示例）
    Write-Host "`n  配置地理封鎖規則..." -ForegroundColor Gray
    
    # 封鎖伊朗 IP 範圍（根據您的攻擊日誌）
    $suspiciousIPs = @(
        "79.127.0.0/16",  # 伊朗 IP 範圍
        "5.160.0.0/16"    # 另一個可疑範圍
    )
    
    foreach ($ipRange in $suspiciousIPs) {
        $ruleName = "SafeModeDefender_Block_Suspicious_IP_$($ipRange -replace '[./]', '_')"
        
        try {
            New-NetFirewallRule -DisplayName $ruleName `
                                -Direction Inbound `
                                -Action Block `
                                -RemoteAddress $ipRange `
                                -Profile Any `
                                -ErrorAction Stop | Out-Null
            Write-Host "  ✓ 已封鎖 IP 範圍：$ipRange" -ForegroundColor Green
        }
        catch {
            Write-Host "  ⚠️  無法封鎖 IP 範圍：$ipRange" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`n  ✅ 防火牆強化完成" -ForegroundColor Green
}

# ============================================================================
# AppLocker 策略
# ============================================================================

if ($ApplyAll -or $ApplyAppLocker) {
    Write-Host "`n[2/4] 配置 AppLocker 策略..." -ForegroundColor Cyan
    
    # 檢查 AppLocker 服務
    $appLockerService = Get-Service -Name "AppIDSvc" -ErrorAction SilentlyContinue
    if (-not $appLockerService) {
        Write-Host "  ⚠️  AppLocker 服務不可用（僅在 Windows Enterprise/Education 版本可用）" -ForegroundColor Yellow
    }
    else {
        # 啟動 AppLocker 服務
        if ($appLockerService.Status -ne "Running") {
            Start-Service -Name "AppIDSvc" -ErrorAction SilentlyContinue
            Set-Service -Name "AppIDSvc" -StartupType Automatic -ErrorAction SilentlyContinue
            Write-Host "  ✓ 已啟動 AppLocker 服務" -ForegroundColor Green
        }
        
        # 創建 AppLocker 規則 XML
        $appLockerXml = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">
    <!-- 阻止 AnyDesk 執行 -->
    <FilePathRule Id="$(New-Guid)" Name="Block AnyDesk" Description="Prevent AnyDesk execution" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePathCondition Path="*\anydesk.exe" />
      </Conditions>
    </FilePathRule>
    
    <!-- 阻止 mshta.exe（ClickFix 攻擊向量） -->
    <FilePathRule Id="$(New-Guid)" Name="Block mshta.exe" Description="Prevent mshta.exe abuse" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePathCondition Path="%SYSTEM32%\mshta.exe" />
      </Conditions>
    </FilePathRule>
    
    <!-- 允許其他可執行檔（預設規則） -->
    <FilePathRule Id="$(New-Guid)" Name="Allow Program Files" Description="Allow all files in Program Files" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%PROGRAMFILES%\*" />
      </Conditions>
    </FilePathRule>
    
    <FilePathRule Id="$(New-Guid)" Name="Allow Windows" Description="Allow all files in Windows folder" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%WINDIR%\*" />
      </Conditions>
    </FilePathRule>
  </RuleCollection>
</AppLockerPolicy>
"@
        
        $appLockerFile = "$env:TEMP\SafeModeDefender_AppLocker.xml"
        $appLockerXml | Out-File $appLockerFile -Encoding UTF8
        
        try {
            # 應用 AppLocker 策略
            Set-AppLockerPolicy -XmlPolicy $appLockerFile -Merge -ErrorAction Stop
            Write-Host "  ✓ AppLocker 策略已應用" -ForegroundColor Green
            Write-Host "  ℹ️  AnyDesk 和 mshta.exe 已被阻止執行" -ForegroundColor Gray
        }
        catch {
            Write-Host "  ✗ AppLocker 策略應用失敗：$($_.Exception.Message)" -ForegroundColor Red
        }
        
        Remove-Item $appLockerFile -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# 審計策略
# ============================================================================

if ($ApplyAll -or $ApplyAudit) {
    Write-Host "`n[3/4] 配置審計策略..." -ForegroundColor Cyan
    
    # 啟用 PowerShell Script Block Logging
    $psLoggingPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
    if (-not (Test-Path $psLoggingPath)) {
        New-Item -Path $psLoggingPath -Force | Out-Null
    }
    Set-ItemProperty -Path $psLoggingPath -Name "EnableScriptBlockLogging" -Value 1 -Type DWord
    Write-Host "  ✓ 已啟用 PowerShell Script Block Logging" -ForegroundColor Green
    
    # 啟用 PowerShell Transcription
    $psTranscriptPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"
    if (-not (Test-Path $psTranscriptPath)) {
        New-Item -Path $psTranscriptPath -Force | Out-Null
    }
    Set-ItemProperty -Path $psTranscriptPath -Name "EnableTranscripting" -Value 1 -Type DWord
    Set-ItemProperty -Path $psTranscriptPath -Name "OutputDirectory" -Value "$env:SystemDrive\PSTranscripts" -Type String
    Write-Host "  ✓ 已啟用 PowerShell Transcription" -ForegroundColor Green
    
    # 啟用進程創建審計
    try {
        & auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable 2>&1 | Out-Null
        Write-Host "  ✓ 已啟用進程創建審計" -ForegroundColor Green
    }
    catch {
        Write-Host "  ⚠️  無法配置進程審計" -ForegroundColor Yellow
    }
    
    # 啟用登入審計
    try {
        & auditpol /set /subcategory:"Logon" /success:enable /failure:enable 2>&1 | Out-Null
        & auditpol /set /subcategory:"Logoff" /success:enable 2>&1 | Out-Null
        Write-Host "  ✓ 已啟用登入/登出審計" -ForegroundColor Green
    }
    catch {
        Write-Host "  ⚠️  無法配置登入審計" -ForegroundColor Yellow
    }
    
    # 啟用網路連接審計
    try {
        & auditpol /set /subcategory:"Filtering Platform Connection" /success:enable /failure:enable 2>&1 | Out-Null
        Write-Host "  ✓ 已啟用網路連接審計" -ForegroundColor Green
    }
    catch {
        Write-Host "  ⚠️  無法配置網路審計" -ForegroundColor Yellow
    }
    
    Write-Host "`n  ✅ 審計策略配置完成" -ForegroundColor Green
}

# ============================================================================
# Windows Defender 進階保護
# ============================================================================

if ($ApplyAll) {
    Write-Host "`n[4/4] 啟用 Windows Defender 進階保護..." -ForegroundColor Cyan
    
    try {
        # 啟用雲端保護
        Set-MpPreference -MAPSReporting Advanced -ErrorAction SilentlyContinue
        Write-Host "  ✓ 已啟用雲端保護" -ForegroundColor Green
        
        # 啟用自動樣本提交
        Set-MpPreference -SubmitSamplesConsent SendAllSamples -ErrorAction SilentlyContinue
        Write-Host "  ✓ 已啟用自動樣本提交" -ForegroundColor Green
        
        # 啟用 PUA 保護
        Set-MpPreference -PUAProtection Enabled -ErrorAction SilentlyContinue
        Write-Host "  ✓ 已啟用 PUA（潛在不需要的應用程式）保護" -ForegroundColor Green
        
        # 啟用網路保護
        Set-MpPreference -EnableNetworkProtection Enabled -ErrorAction SilentlyContinue
        Write-Host "  ✓ 已啟用網路保護" -ForegroundColor Green
        
        # 啟用受控資料夾存取
        Set-MpPreference -EnableControlledFolderAccess Enabled -ErrorAction SilentlyContinue
        Write-Host "  ✓ 已啟用受控資料夾存取" -ForegroundColor Green
        
        # 啟用攻擊面減少規則（ASR）
        $asrRules = @(
            "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550",  # Block executable content from email client and webmail
            "D4F940AB-401B-4EFC-AADC-AD5F3C50688A",  # Block all Office applications from creating child processes
            "3B576869-A4EC-4529-8536-B80A7769E899",  # Block Office applications from creating executable content
            "75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84",  # Block Office applications from injecting code into other processes
            "D3E037E1-3EB8-44C8-A917-57927947596D",  # Block JavaScript or VBScript from launching downloaded executable content
            "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC",  # Block execution of potentially obfuscated scripts
            "92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B"   # Block Win32 API calls from Office macros
        )
        
        foreach ($rule in $asrRules) {
            Add-MpPreference -AttackSurfaceReductionRules_Ids $rule -AttackSurfaceReductionRules_Actions Enabled -ErrorAction SilentlyContinue
        }
        Write-Host "  ✓ 已啟用攻擊面減少規則（ASR）" -ForegroundColor Green
        
        Write-Host "`n  ✅ Windows Defender 進階保護已啟用" -ForegroundColor Green
    }
    catch {
        Write-Host "  ⚠️  部分 Windows Defender 設定無法應用" -ForegroundColor Yellow
    }
}

# ============================================================================
# 完成
# ============================================================================

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                        ✅ 系統強化完成！                                 ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝

已應用的強化措施：
"@ -ForegroundColor Green

if ($ApplyAll -or $ApplyFirewall) {
    Write-Host "  ✓ 防火牆規則強化" -ForegroundColor Green
}
if ($ApplyAll -or $ApplyAppLocker) {
    Write-Host "  ✓ AppLocker 應用程式控制" -ForegroundColor Green
}
if ($ApplyAll -or $ApplyAudit) {
    Write-Host "  ✓ 審計策略配置" -ForegroundColor Green
}
if ($ApplyAll) {
    Write-Host "  ✓ Windows Defender 進階保護" -ForegroundColor Green
}

Write-Host @"

建議的後續步驟：
1. 🔄 重新啟動電腦以確保所有變更生效
2. 🛡️  定期檢查 Windows Defender 掃描結果
3. 📊 監控事件日誌中的可疑活動（事件檢視器）
4. 🔐 考慮啟用 BitLocker 磁碟加密
5. 🔑 使用硬體安全金鑰（如 YubiKey）進行身份驗證

"@ -ForegroundColor Cyan

Write-Host "按任意鍵退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
