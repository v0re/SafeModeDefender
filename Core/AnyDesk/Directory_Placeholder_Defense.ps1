# ============================================================================
# Directory_Placeholder_Defense.ps1 - AnyDesk 目錄佔位防禦（實驗性）
# 
# 功能：通過佔用 AnyDesk 配置目錄來阻止其正常運作
# 警告：此腳本為實驗性質，需要在虛擬機中測試後再部署到生產環境
# ============================================================================

<#
.SYNOPSIS
    AnyDesk 目錄佔位防禦腳本（實驗性）

.DESCRIPTION
    此腳本實施「目錄佔位防禦」策略，通過預先創建 AnyDesk 配置目錄並移除所有權限，
    阻止 AnyDesk 正常運作，從而防止攻擊者讀取憑證檔案。

    **警告**：此腳本為實驗性質，可能會影響合法的 AnyDesk 使用。
    請務必在虛擬機中測試後再部署到生產環境。

.PARAMETER Mode
    防禦模式：
    - "Block"：創建佔位目錄並移除所有權限（完全阻止）
    - "ReadOnly"：創建佔位目錄並設置為只讀（允許讀取但不允許寫入）
    - "Junction"：使用 NTFS 接合點指向不存在的位置（進階阻止）
    - "Remove"：移除所有佔位目錄，恢復正常

.PARAMETER Test
    測試模式，僅顯示將要執行的操作，不實際執行

.EXAMPLE
    .\Directory_Placeholder_Defense.ps1 -Mode Block
    創建佔位目錄並完全阻止 AnyDesk 訪問

.EXAMPLE
    .\Directory_Placeholder_Defense.ps1 -Mode ReadOnly
    創建只讀佔位目錄

.EXAMPLE
    .\Directory_Placeholder_Defense.ps1 -Mode Junction
    使用 NTFS 接合點進行進階阻止

.EXAMPLE
    .\Directory_Placeholder_Defense.ps1 -Mode Remove
    移除所有佔位目錄，恢復正常

.EXAMPLE
    .\Directory_Placeholder_Defense.ps1 -Mode Block -Test
    測試模式，僅顯示操作但不執行

.NOTES
    作者：Manus AI
    版本：1.0 (實驗性)
    日期：2026-02-19
    警告：此腳本需要管理員權限
    
    **重要提示**：
    1. 此防禦策略未經 AnyDesk 官方驗證
    2. 可能會影響合法的 AnyDesk 使用
    3. 攻擊者如果已獲得管理員權限，可以輕易繞過此防禦
    4. 建議結合其他防禦措施（防火牆、AppLocker 等）一起使用
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Block", "ReadOnly", "Junction", "Remove")]
    [string]$Mode,
    
    [switch]$Test
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
║            AnyDesk 目錄佔位防禦工具 v1.0 (實驗性)                        ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝

⚠️  警告：此工具為實驗性質，請在虛擬機中測試後再部署到生產環境。

"@ -ForegroundColor Yellow

# 定義所有可能的 AnyDesk 配置目錄
$targetDirectories = @(
    "$env:APPDATA\AnyDesk",
    "$env:ProgramData\AnyDesk",
    "$env:LOCALAPPDATA\AnyDesk",
    "$env:TEMP\AnyDesk"
)

Write-Host "目標目錄：" -ForegroundColor Cyan
foreach ($dir in $targetDirectories) {
    Write-Host "  - $dir" -ForegroundColor Gray
}

Write-Host "`n選擇的模式：$Mode`n" -ForegroundColor Cyan

# ============================================================================
# 模式：Block（完全阻止）
# ============================================================================

if ($Mode -eq "Block") {
    Write-Host "[模式] 完全阻止 - 創建佔位目錄並移除所有權限" -ForegroundColor Yellow
    
    foreach ($dir in $targetDirectories) {
        Write-Host "`n處理：$dir" -ForegroundColor Cyan
        
        # 檢查目錄是否已存在
        if (Test-Path $dir) {
            Write-Host "  ⚠️  目錄已存在，將備份後刪除" -ForegroundColor Yellow
            
            if (-not $Test) {
                # 備份現有目錄
                $backupPath = "$dir`_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                try {
                    Move-Item -Path $dir -Destination $backupPath -Force -ErrorAction Stop
                    Write-Host "  ✓ 已備份到：$backupPath" -ForegroundColor Green
                }
                catch {
                    Write-Host "  ✗ 備份失敗：$($_.Exception.Message)" -ForegroundColor Red
                    continue
                }
            }
            else {
                Write-Host "  [測試] 將備份到：$dir`_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')" -ForegroundColor Gray
            }
        }
        
        # 創建佔位目錄
        if (-not $Test) {
            try {
                New-Item -Path $dir -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Host "  ✓ 已創建佔位目錄" -ForegroundColor Green
            }
            catch {
                Write-Host "  ✗ 創建失敗：$($_.Exception.Message)" -ForegroundColor Red
                continue
            }
        }
        else {
            Write-Host "  [測試] 將創建佔位目錄" -ForegroundColor Gray
        }
        
        # 移除所有權限
        if (-not $Test) {
            try {
                $acl = Get-Acl $dir
                $acl.SetAccessRuleProtection($true, $false)  # 禁用繼承並移除所有繼承的規則
                $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
                Set-Acl -Path $dir -AclObject $acl -ErrorAction Stop
                Write-Host "  ✓ 已移除所有權限" -ForegroundColor Green
            }
            catch {
                Write-Host "  ✗ 權限設置失敗：$($_.Exception.Message)" -ForegroundColor Red
            }
        }
        else {
            Write-Host "  [測試] 將移除所有權限" -ForegroundColor Gray
        }
    }
}

# ============================================================================
# 模式：ReadOnly（只讀）
# ============================================================================

elseif ($Mode -eq "ReadOnly") {
    Write-Host "[模式] 只讀 - 創建佔位目錄並設置為只讀" -ForegroundColor Yellow
    
    foreach ($dir in $targetDirectories) {
        Write-Host "`n處理：$dir" -ForegroundColor Cyan
        
        # 檢查目錄是否已存在
        if (Test-Path $dir) {
            Write-Host "  ⚠️  目錄已存在，將備份後刪除" -ForegroundColor Yellow
            
            if (-not $Test) {
                $backupPath = "$dir`_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                try {
                    Move-Item -Path $dir -Destination $backupPath -Force -ErrorAction Stop
                    Write-Host "  ✓ 已備份到：$backupPath" -ForegroundColor Green
                }
                catch {
                    Write-Host "  ✗ 備份失敗：$($_.Exception.Message)" -ForegroundColor Red
                    continue
                }
            }
            else {
                Write-Host "  [測試] 將備份到：$dir`_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')" -ForegroundColor Gray
            }
        }
        
        # 創建佔位目錄
        if (-not $Test) {
            try {
                New-Item -Path $dir -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Host "  ✓ 已創建佔位目錄" -ForegroundColor Green
            }
            catch {
                Write-Host "  ✗ 創建失敗：$($_.Exception.Message)" -ForegroundColor Red
                continue
            }
        }
        else {
            Write-Host "  [測試] 將創建佔位目錄" -ForegroundColor Gray
        }
        
        # 設置為只讀
        if (-not $Test) {
            try {
                $acl = Get-Acl $dir
                $acl.SetAccessRuleProtection($true, $false)
                
                # 添加只讀權限給所有使用者
                $readOnlyRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    "Everyone",
                    "ReadAndExecute",
                    "ContainerInherit,ObjectInherit",
                    "None",
                    "Allow"
                )
                $acl.AddAccessRule($readOnlyRule)
                
                Set-Acl -Path $dir -AclObject $acl -ErrorAction Stop
                Write-Host "  ✓ 已設置為只讀" -ForegroundColor Green
            }
            catch {
                Write-Host "  ✗ 權限設置失敗：$($_.Exception.Message)" -ForegroundColor Red
            }
        }
        else {
            Write-Host "  [測試] 將設置為只讀" -ForegroundColor Gray
        }
    }
}

# ============================================================================
# 模式：Junction（NTFS 接合點）
# ============================================================================

elseif ($Mode -eq "Junction") {
    Write-Host "[模式] NTFS 接合點 - 指向不存在的位置" -ForegroundColor Yellow
    Write-Host "⚠️  警告：此模式使用的技術與 CVE-2024-12754 漏洞相同，請謹慎使用！" -ForegroundColor Red
    
    foreach ($dir in $targetDirectories) {
        Write-Host "`n處理：$dir" -ForegroundColor Cyan
        
        # 檢查目錄是否已存在
        if (Test-Path $dir) {
            Write-Host "  ⚠️  目錄已存在，將備份後刪除" -ForegroundColor Yellow
            
            if (-not $Test) {
                $backupPath = "$dir`_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                try {
                    Move-Item -Path $dir -Destination $backupPath -Force -ErrorAction Stop
                    Write-Host "  ✓ 已備份到：$backupPath" -ForegroundColor Green
                }
                catch {
                    Write-Host "  ✗ 備份失敗：$($_.Exception.Message)" -ForegroundColor Red
                    continue
                }
            }
            else {
                Write-Host "  [測試] 將備份到：$dir`_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')" -ForegroundColor Gray
            }
        }
        
        # 創建 NTFS 接合點
        $targetPath = "C:\NonExistent\AnyDesk_$(Get-Random)"
        
        if (-not $Test) {
            try {
                & cmd /c mklink /J "$dir" "$targetPath" 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✓ 已創建接合點：$dir -> $targetPath" -ForegroundColor Green
                }
                else {
                    Write-Host "  ✗ 創建接合點失敗" -ForegroundColor Red
                }
            }
            catch {
                Write-Host "  ✗ 創建接合點失敗：$($_.Exception.Message)" -ForegroundColor Red
            }
        }
        else {
            Write-Host "  [測試] 將創建接合點：$dir -> $targetPath" -ForegroundColor Gray
        }
    }
}

# ============================================================================
# 模式：Remove（移除）
# ============================================================================

elseif ($Mode -eq "Remove") {
    Write-Host "[模式] 移除 - 刪除所有佔位目錄並恢復正常" -ForegroundColor Yellow
    
    foreach ($dir in $targetDirectories) {
        Write-Host "`n處理：$dir" -ForegroundColor Cyan
        
        if (Test-Path $dir) {
            # 檢查是否為接合點
            $item = Get-Item $dir -Force
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                Write-Host "  ℹ️  檢測到接合點" -ForegroundColor Gray
                
                if (-not $Test) {
                    try {
                        & cmd /c rmdir "$dir" 2>&1 | Out-Null
                        Write-Host "  ✓ 已移除接合點" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "  ✗ 移除失敗：$($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "  [測試] 將移除接合點" -ForegroundColor Gray
                }
            }
            else {
                # 普通目錄
                if (-not $Test) {
                    try {
                        # 先恢復權限
                        $acl = Get-Acl $dir
                        $acl.SetAccessRuleProtection($false, $true)  # 啟用繼承
                        Set-Acl -Path $dir -AclObject $acl -ErrorAction SilentlyContinue
                        
                        # 刪除目錄
                        Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
                        Write-Host "  ✓ 已移除佔位目錄" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "  ✗ 移除失敗：$($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "  [測試] 將移除佔位目錄" -ForegroundColor Gray
                }
            }
        }
        else {
            Write-Host "  ℹ️  目錄不存在，無需移除" -ForegroundColor Gray
        }
    }
}

# ============================================================================
# 完成
# ============================================================================

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                        ✅ 操作完成！                                     ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

if ($Test) {
    Write-Host "⚠️  這是測試模式，實際上沒有執行任何操作。" -ForegroundColor Yellow
    Write-Host "   移除 -Test 參數以實際執行。`n" -ForegroundColor Yellow
}
else {
    Write-Host "後續步驟：" -ForegroundColor Cyan
    Write-Host "1. 🧪 測試 AnyDesk 是否能正常啟動" -ForegroundColor White
    Write-Host "2. 📊 檢查事件日誌中的錯誤訊息" -ForegroundColor White
    Write-Host "3. 🔍 監控 AnyDesk 是否嘗試使用其他目錄" -ForegroundColor White
    Write-Host "4. 📝 記錄測試結果並回報" -ForegroundColor White
    Write-Host "`n如需恢復正常，請執行：" -ForegroundColor Cyan
    Write-Host "  .\Directory_Placeholder_Defense.ps1 -Mode Remove`n" -ForegroundColor Gray
}

Write-Host "按任意鍵退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
