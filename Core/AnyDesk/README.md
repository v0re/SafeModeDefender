# AnyDesk 安全模塊 (I1)

此目錄包含 SafeModeDefender 的 AnyDesk 安全檢測、清理和預防相關的所有腳本。

## 檔案結構

-   `I1_AnyDesk_Security.ps1`: 主檢測模塊，整合所有子檢測功能。
-   `Advanced_Attack_Detection.ps1`: 進階攻擊檢測函數庫，包含 GPU 攻擊、GPO 篡改等檢測邏輯。
-   `Emergency_Cleanup.ps1`: 緊急清理腳本，用於在系統被入侵後執行完整的清理和修復。
-   `System_Hardening.ps1`: 系統強化腳本，用於預防未來的攻擊。

## 功能

### 1. 深度檢測

-   **GPU 渲染攻擊**：檢測 Direct3D 錯誤、顯卡驅動程式衝突和異常的 GPU 使用率。
-   **GPO 篡改**：檢測註冊表中的封鎖策略，識別被禁用的系統管理工具。
-   **ClickFix 社交工程**：分析 PowerShell 歷史記錄、防火牆規則和 `mshta.exe` 執行記錄。
-   **隱私模式濫用**：檢查配置檔案和日誌，發現攻擊者隱藏操作的跡象。
-   **已知漏洞**：檢測 CVE-2024-52940 和 CVE-2024-12754 的攻擊指標。
-   **憑證冒用**：分析 `service.conf` 和 `user.conf`，檢測身份冒用風險。

### 2. 緊急清理

-   **GPO 封鎖突破**：提供離線修復指南，刪除被污染的原則檔案。
-   **AnyDesk 根除**：徹底移除 AnyDesk 進程、服務、配置檔案和註冊表項。
-   **鑑識證據備份**：在清理前自動備份所有相關日誌和配置檔案。

### 3. 系統強化

-   **防火牆強化**：封鎖 AnyDesk 常用端口和已知的惡意 IP 範圍。
-   **AppLocker 策略**：阻止 `anydesk.exe` 和 `mshta.exe` 的執行。
-   **審計策略**：啟用進程創建、登入/登出和 PowerShell 腳本塊日誌記錄。
-   **Windows Defender 進階保護**：啟用 ASR 規則、PUA 保護和受控資料夾存取。

## 使用方法

### 執行完整檢測

```powershell
.\SafeModeDefender.bat --cli --module I1_AnyDesk_Security
```

### 執行緊急清理

**警告：** 此腳本會對系統進行重大變更，請在了解風險後執行。

```powershell
# 進入 Core\AnyDesk 目錄
cd Core\AnyDesk

# 執行清理腳本
.\Emergency_Cleanup.ps1
```

### 應用系統強化

```powershell
# 進入 Core\AnyDesk 目錄
cd Core\AnyDesk

# 應用所有強化措施
.\System_Hardening.ps1 -ApplyAll
```

## 依賴

-   Windows 10 或更高版本
-   PowerShell 5.1 或更高版本
-   管理員權限

## 注意事項

-   在執行任何清理或強化操作之前，請務必備份重要資料。
-   `Emergency_Cleanup.ps1` 腳本執行後，強烈建議重新安裝作業系統以確保完全清除攻擊者的持久化機制。
-   `System_Hardening.ps1` 腳本中的某些強化措施（如 AppLocker）僅在 Windows Enterprise/Education 版本中可用。
