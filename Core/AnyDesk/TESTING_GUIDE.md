# AnyDesk 目錄佔位防禦測試指南

## 測試目的

驗證「目錄佔位防禦」策略的有效性，確定 AnyDesk 在配置目錄不可用時的實際行為。

## 測試環境要求

### 必要條件
- ✅ Windows 虛擬機（建議使用 VMware 或 VirtualBox）
- ✅ 乾淨的 Windows 10/11 安裝
- ✅ 管理員權限
- ✅ 網路連接（用於下載 AnyDesk）
- ✅ 快照功能（用於快速恢復測試環境）

### 建議配置
- CPU：2 核心
- RAM：4GB
- 硬碟：40GB

## 測試前準備

### 1. 創建虛擬機快照

在開始測試前，創建一個乾淨的系統快照，以便在測試後快速恢復。

```powershell
# 在 VMware 中，使用 GUI 創建快照
# 快照名稱：Clean_System_Before_AnyDesk_Test
```

### 2. 下載 AnyDesk

從官方網站下載最新版本的 AnyDesk：
- 官方網站：https://anydesk.com/en/downloads/windows
- 下載便攜版（Portable）和安裝版（Installer）

### 3. 準備測試腳本

將 `Directory_Placeholder_Defense.ps1` 複製到虛擬機中。

## 測試案例

### 測試案例 1：Block 模式（完全阻止）

**目標**：驗證 AnyDesk 在配置目錄完全不可訪問時的行為。

**步驟**：

1. **執行防禦腳本**（測試模式）：
   ```powershell
   .\Directory_Placeholder_Defense.ps1 -Mode Block -Test
   ```
   檢查輸出，確認將要執行的操作。

2. **執行防禦腳本**（實際執行）：
   ```powershell
   .\Directory_Placeholder_Defense.ps1 -Mode Block
   ```

3. **驗證佔位目錄**：
   ```powershell
   # 檢查目錄是否存在
   Test-Path "$env:APPDATA\AnyDesk"
   Test-Path "$env:ProgramData\AnyDesk"
   
   # 檢查目錄權限
   Get-Acl "$env:APPDATA\AnyDesk" | Format-List
   ```

4. **嘗試啟動 AnyDesk（便攜版）**：
   - 雙擊 `AnyDesk.exe`
   - 觀察是否能正常啟動
   - 記錄任何錯誤訊息

5. **檢查事件日誌**：
   ```powershell
   # 檢查應用程式日誌
   Get-EventLog -LogName Application -Source "AnyDesk*" -Newest 10
   
   # 檢查系統日誌中的錯誤
   Get-EventLog -LogName System -EntryType Error -Newest 10
   ```

6. **檢查 AnyDesk 是否使用了其他目錄**：
   ```powershell
   # 搜尋所有 AnyDesk 相關目錄
   Get-ChildItem -Path C:\ -Recurse -Directory -Filter "*AnyDesk*" -ErrorAction SilentlyContinue
   
   # 檢查臨時目錄
   Get-ChildItem -Path $env:TEMP -Recurse -Filter "*AnyDesk*" -ErrorAction SilentlyContinue
   ```

7. **記錄結果**：
   - AnyDesk 是否成功啟動？
   - 是否顯示錯誤訊息？
   - 是否使用了其他目錄？
   - 是否生成了新的 AnyDesk ID？

8. **清理**：
   ```powershell
   .\Directory_Placeholder_Defense.ps1 -Mode Remove
   ```

9. **恢復快照**，準備下一個測試案例。

**預期結果**：
- ❌ AnyDesk 無法啟動，顯示「無法創建配置目錄」錯誤
- ✅ AnyDesk 啟動但使用臨時目錄
- ✅ AnyDesk 提示使用者選擇配置目錄

---

### 測試案例 2：ReadOnly 模式（只讀）

**目標**：驗證 AnyDesk 在配置目錄只讀時的行為。

**步驟**：

1. **執行防禦腳本**：
   ```powershell
   .\Directory_Placeholder_Defense.ps1 -Mode ReadOnly
   ```

2. **嘗試啟動 AnyDesk（便攜版）**。

3. **觀察 AnyDesk 行為**：
   - 是否能讀取空目錄？
   - 是否嘗試寫入配置檔案？
   - 是否顯示錯誤訊息？

4. **檢查目錄內容**：
   ```powershell
   Get-ChildItem "$env:APPDATA\AnyDesk" -Force
   ```

5. **記錄結果**。

6. **清理並恢復快照**。

**預期結果**：
- ❌ AnyDesk 無法啟動，顯示「無法寫入配置檔案」錯誤
- ✅ AnyDesk 啟動但功能受限（無法保存設定）

---

### 測試案例 3：Junction 模式（NTFS 接合點）

**目標**：驗證 AnyDesk 在配置目錄為接合點時的行為。

**步驟**：

1. **執行防禦腳本**：
   ```powershell
   .\Directory_Placeholder_Defense.ps1 -Mode Junction
   ```

2. **驗證接合點**：
   ```powershell
   # 檢查是否為接合點
   $item = Get-Item "$env:APPDATA\AnyDesk" -Force
   $item.Attributes -band [System.IO.FileAttributes]::ReparsePoint
   
   # 顯示接合點目標
   & cmd /c dir /AL "$env:APPDATA"
   ```

3. **嘗試啟動 AnyDesk（便攜版）**。

4. **觀察 AnyDesk 行為**：
   - 是否嘗試訪問接合點目標？
   - 是否顯示錯誤訊息？
   - 是否崩潰？

5. **記錄結果**。

6. **清理並恢復快照**。

**預期結果**：
- ❌ AnyDesk 無法啟動，顯示「路徑不存在」錯誤
- ❌ AnyDesk 崩潰

---

### 測試案例 4：安裝版 AnyDesk

**目標**：驗證安裝版 AnyDesk 的行為（使用 `%ProgramData%`）。

**步驟**：

1. **執行防禦腳本**：
   ```powershell
   .\Directory_Placeholder_Defense.ps1 -Mode Block
   ```

2. **安裝 AnyDesk**：
   - 執行 AnyDesk 安裝程式
   - 觀察安裝過程是否成功
   - 記錄任何錯誤訊息

3. **嘗試啟動已安裝的 AnyDesk**。

4. **記錄結果**。

5. **清理並恢復快照**。

**預期結果**：
- ❌ 安裝失敗，顯示「無法創建配置目錄」錯誤
- ✅ 安裝成功但 AnyDesk 無法啟動

---

### 測試案例 5：AnyDesk 已運行時應用防禦

**目標**：驗證在 AnyDesk 已經運行時應用防禦的效果。

**步驟**：

1. **啟動 AnyDesk（便攜版）**，確保它正常運行。

2. **記錄 AnyDesk ID 和配置目錄位置**。

3. **執行防禦腳本**：
   ```powershell
   .\Directory_Placeholder_Defense.ps1 -Mode Block
   ```
   注意：腳本會備份現有目錄。

4. **重啟 AnyDesk**。

5. **觀察 AnyDesk 行為**。

6. **記錄結果**。

7. **清理並恢復快照**。

**預期結果**：
- ✅ AnyDesk 生成新的 ID（因為舊的配置被備份）
- ❌ AnyDesk 無法啟動

---

## 結果記錄表

| 測試案例 | AnyDesk 版本 | 是否啟動 | 錯誤訊息 | 使用的目錄 | 新 ID | 備註 |
|---------|-------------|---------|---------|-----------|-------|------|
| Block - 便攜版 | | | | | | |
| Block - 安裝版 | | | | | | |
| ReadOnly - 便攜版 | | | | | | |
| ReadOnly - 安裝版 | | | | | | |
| Junction - 便攜版 | | | | | | |
| Junction - 安裝版 | | | | | | |
| 已運行時應用 | | | | | | |

## 進階測試

### 測試 AnyDesk 的回退機制

1. **佔用所有已知目錄**：
   - `%APPDATA%\AnyDesk`
   - `%ProgramData%\AnyDesk`
   - `%LOCALAPPDATA%\AnyDesk`
   - `%TEMP%\AnyDesk`

2. **使用 Process Monitor 監控 AnyDesk**：
   - 下載 Sysinternals Process Monitor
   - 設置過濾器：Process Name is anydesk.exe
   - 啟動 AnyDesk
   - 觀察它嘗試訪問哪些目錄

3. **分析結果**，確定 AnyDesk 是否有未記錄的回退目錄。

### 測試對合法使用的影響

1. **創建一個合法的 AnyDesk 配置**。

2. **應用防禦**。

3. **嘗試連接到遠端電腦**。

4. **記錄對合法使用的影響**。

## 測試完成後

### 1. 整理測試結果

將所有測試結果整理成報告，包括：
- 每個測試案例的詳細結果
- 截圖和日誌
- AnyDesk 的實際行為
- 防禦策略的有效性評估

### 2. 提交反饋

將測試結果提交給 SafeModeDefender 開發團隊，幫助改進防禦策略。

### 3. 決定是否部署

根據測試結果，決定是否在生產環境中部署此防禦策略。

**建議**：
- ✅ 如果 AnyDesk 完全無法啟動，且沒有回退機制，則此防禦有效
- ⚠️ 如果 AnyDesk 使用臨時目錄，則需要擴展佔位目錄清單
- ❌ 如果對合法使用影響過大，則不建議部署

## 安全提示

1. **僅在虛擬機中測試**：不要在生產環境中直接測試。

2. **備份重要資料**：在測試前備份所有重要資料。

3. **監控系統行為**：使用 Process Monitor 和事件日誌監控系統行為。

4. **結合其他防禦**：目錄佔位防禦不應單獨使用，應結合防火牆、AppLocker 等其他防禦措施。

5. **定期更新測試**：AnyDesk 可能會更新其行為，定期重新測試以確保防禦仍然有效。

---

**測試愉快！** 🧪

如有任何問題或發現，請立即回報給 SafeModeDefender 開發團隊。
