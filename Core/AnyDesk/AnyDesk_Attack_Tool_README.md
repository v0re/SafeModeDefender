# AnyDesk 自動化攻擊工具 - 使用說明與安全警告

---

## ⚠️ **極度危險 - 僅供授權測試使用** ⚠️

此工具是一個**滲透測試工具**，旨在模擬真實的 AnyDesk 攻擊鏈。**嚴禁在未經授權的系統上使用此工具！**

**所有使用此工具的行為都將被記錄，並可能觸發目標系統的安全警報。**

**開發者和 SafeModeDefender 項目對任何濫用此工具造成的後果概不負責。**

---

## ✨ 功能

本工具整合了多種已知的 AnyDesk 攻擊技術，用於驗證防禦措施和檢測能力：

- ✅ **CVE-2024-52940 IP 洩露攻擊**
- ✅ **黑屏模式 (Privacy Mode)**
- ✅ **隱藏模式 (Plain Mode)**
- ✅ **TCP 直連 (無 Proxy)**
- ✅ **自動檔案傳輸**
- ✅ **暴力破解密碼**

---

## 🚀 如何使用

### 1. **環境準備**

- **攻擊機**：一台安裝了 AnyDesk 的 Windows 電腦
- **目標機**：一台安裝了 AnyDesk 的 Windows 電腦（用於測試）
- **網路**：確保兩台電腦可以互相訪問

### 2. **下載工具**

從 SafeModeDefender GitHub 儲存庫下載 `AnyDesk_Attack_Tool.ps1`。

### 3. **執行攻擊**

以**管理員權限**打開 PowerShell，然後執行以下命令：

#### 基礎連接（需要受害者授權）
```powershell
.\AnyDesk_Attack_Tool.ps1 -TargetID <目標ID>
```

#### 使用密碼連接
```powershell
.\AnyDesk_Attack_Tool.ps1 -TargetID <目標ID> -Password <密碼>
```

#### 暴力破解密碼
```powershell
# 創建一個密碼清單檔案 (passwords.txt)
# 每行一個密碼

.\AnyDesk_Attack_Tool.ps1 -TargetID <目標ID> -PasswordList .\passwords.txt
```

#### 完整攻擊鏈（整合所有技術）
```powershell
.\AnyDesk_Attack_Tool.ps1 -TargetID <目標ID> `
    -Password <密碼> `
    -EnableIPLeak `
    -EnableBlackScreen `
    -EnablePlainMode `
    -DisableProxy `
    -EnableFileTransfer `
    -FileToTransfer "C:\path\to\your\file.txt"
```

---

## 📋 參數說明

| 參數 | 說明 |
|---|---|
| `-TargetID` | **必需**。目標 AnyDesk 的 ID 或別名。 |
| `-Password` | 可選。用於連接的密碼。 |
| `-PasswordList` | 可選。暴力破解的密碼清單檔案路徑。 |
| `-FileToTransfer` | 可選。要傳輸的檔案路徑。 |
| `-EnableBlackScreen` | 可選。啟用黑屏模式（需要在連接後手動操作）。 |
| `-EnablePlainMode` | 可選。啟用隱藏模式（無邊框視窗）。 |
| `-DisableProxy` | 可選。禁用代理，強制 TCP 直連。 |
| `-EnableIPLeak` | 可選。執行 CVE-2024-52940 IP 洩露攻擊。 |
| `-EnableFileTransfer` | 可選。啟用檔案傳輸模式。 |
| `-AnyDeskPath` | 可選。AnyDesk 可執行檔案的路徑。 |
| `-LogFile` | 可選。日誌檔案的路徑。 |

---

## 🛡️ 如何防禦這些攻擊

### 1. **目錄佔位防禦**

這是**最有效**的防禦措施！

```powershell
# 應用防禦
Remove-Item "$env:APPDATA\AnyDesk" -Recurse -Force
New-Item "$env:APPDATA\AnyDesk" -ItemType File

# 移除防禦（如果需要合法使用）
Remove-Item "$env:APPDATA\AnyDesk" -Force
mkdir "$env:APPDATA\AnyDesk"
```

### 2. **使用強密碼**

- 20+ 字元
- 包含大小寫字母、數字和特殊符號
- 不要重複使用密碼

### 3. **啟用雙因素認證**

如果您的 AnyDesk 版本支持，請務必啟用。

### 4. **監控 AnyDesk 活動**

- 使用 SafeModeDefender 的 `I1_AnyDesk_Security.ps1` 模塊
- 定期檢查 `ad.trace` 日誌
- 監控可疑的 CLI 參數使用

### 5. **限制訪問**

- 在 AnyDesk 設置中，只允許特定的 ID 連接
- 使用防火牆限制 7070 端口的訪問

---

## 🧪 測試場景

### 1. **測試目錄佔位防禦**

1. 在目標機上應用目錄佔位防禦
2. 在攻擊機上執行攻擊工具
3. **預期結果**：攻擊失敗，AnyDesk 無法啟動

### 2. **測試密碼強度**

1. 在目標機上設置一個弱密碼
2. 在攻擊機上使用暴力破解模式
3. **預期結果**：攻擊成功，找到密碼

### 3. **測試檢測能力**

1. 在目標機上運行 SafeModeDefender 的監控模塊
2. 在攻擊機上執行攻擊工具
3. **預期結果**：SafeModeDefender 檢測到可疑活動並發出警報

---

## 📝 法律與道德聲明

**此工具僅供教育和授權的滲透測試使用。**

**請遵守您所在地區的法律法規。**

**不要在任何您沒有明確授權的系統上使用此工具。**
