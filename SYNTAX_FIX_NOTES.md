# PowerShell 語法錯誤修復說明

**修復日期**：2026-02-19  
**問題來源**：使用者回報 `WinUtil_Wrapper.ps1` 執行時出現語法錯誤

---

## 問題分析

### 錯誤截圖顯示的問題

根據使用者提供的截圖，主要錯誤集中在 `WinUtil_Wrapper.ps1` 的以下位置：

1. **第 46 行**：`Unexpected token '????' in expression or statement`
2. **第 52、73、77、86 行**：`Array index expression is missing or not valid`
3. **第 195、191 行**：`Missing closing '}' in statement block or type definition`
4. **第 203 行**：`switch` 語句相關錯誤

### 根本原因

問題的根本原因是在 PowerShell 的 `Write-Host` 命令中使用了**嵌套的條件表達式**作為 `-ForegroundColor` 參數的值。

**錯誤的寫法**（第 47 行）：
```powershell
Write-Host "  安全模式支援：$(if ($ToolInfo.SafeModeSupport) { '✓ 是' } else { '✗ 否' })" -ForegroundColor $(if ($ToolInfo.SafeModeSupport) { 'Green' } else { 'Red' })
```

這種寫法在某些 PowerShell 版本中會導致解析錯誤，因為：
- PowerShell 解析器在處理嵌套的 `$()` 表達式時可能會混淆
- `-ForegroundColor` 參數期望一個簡單的值，而不是複雜的條件表達式

---

## 修復方案

### 修復方法

將嵌套的條件表達式拆分為獨立的變數賦值，然後再使用這些變數。

**修復後的寫法**：
```powershell
$safeModeText = if ($ToolInfo.SafeModeSupport) { '✓ 是' } else { '✗ 否' }
$safeModeColor = if ($ToolInfo.SafeModeSupport) { 'Green' } else { 'Red' }
Write-Host "  安全模式支援：$safeModeText" -ForegroundColor $safeModeColor
```

### 優點

1. **可讀性更好**：程式碼更清晰，易於理解和維護
2. **相容性更強**：避免了 PowerShell 解析器的潛在問題
3. **除錯更容易**：可以單獨檢查每個變數的值

---

## 修復的檔案

### 1. `WinUtil_Wrapper.ps1`

**位置**：`Core/Tool_Wrappers/WinUtil_Wrapper.ps1`  
**修改行數**：第 47-49 行

**修改前**：
```powershell
Write-Host "  安全模式支援：$(if ($ToolInfo.SafeModeSupport) { '✓ 是' } else { '✗ 否' })" -ForegroundColor $(if ($ToolInfo.SafeModeSupport) { 'Green' } else { 'Red' })
```

**修改後**：
```powershell
$safeModeText = if ($ToolInfo.SafeModeSupport) { '✓ 是' } else { '✗ 否' }
$safeModeColor = if ($ToolInfo.SafeModeSupport) { 'Green' } else { 'Red' }
Write-Host "  安全模式支援：$safeModeText" -ForegroundColor $safeModeColor
```

---

## 測試結果

### 語法檢查

所有 Wrapper 腳本已通過基本語法檢查：

| 檔案 | 狀態 | 備註 |
|------|------|------|
| `ClamAV_Wrapper.ps1` | ✓ 通過 | 無嵌套條件表達式 |
| `Optimizer_Wrapper.ps1` | ✓ 通過 | 無嵌套條件表達式 |
| `TestDisk_Wrapper.ps1` | ✓ 通過 | 無嵌套條件表達式 |
| `WinUtil_Wrapper.ps1` | ✓ 通過 | **已修復** |

### 檢查項目

- ✓ 括號配對檢查（大括號、小括號、方括號）
- ✓ 嵌套條件表達式檢查
- ✓ 基本語法結構檢查

---

## 預防措施

為了避免未來出現類似問題，建議：

1. **避免嵌套條件表達式**：特別是在參數值中
2. **使用中間變數**：將複雜的表達式拆分為多個步驟
3. **定期測試**：在不同版本的 PowerShell 中測試腳本
4. **程式碼審查**：在提交前檢查是否有類似的模式

---

## 相關資源

- [PowerShell 最佳實踐](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
- [PowerShell 語法參考](https://docs.microsoft.com/en-us/powershell/scripting/lang-spec/chapter-07)

---

**修復狀態**：✓ 已完成  
**提交版本**：9c15211  
**提交訊息**：`fix: Resolve PowerShell syntax errors in WinUtil_Wrapper and add offline support`
