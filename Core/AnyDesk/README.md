# AnyDesk 安全檢測模塊

此目錄包含 SafeModeDefender 的 AnyDesk 安全檢測模塊。

## 檔案

- `I1_AnyDesk_Security.ps1`：核心檢測腳本

## 功能

- 檢測 AnyDesk 安裝、版本和數位簽章
- 分析配置檔案的安全性
- 檢測 CVE-2024-52940 和 CVE-2024-12754 漏洞
- 監控網路連接和進程行為
- 分析日誌檔案
- 生成詳細的 JSON 報告

## 使用方法

```powershell
# 執行 AnyDesk 安全檢測
.\SafeModeDefender.bat --cli --module I1_AnyDesk_Security
```
