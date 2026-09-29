# goldenrave

goldenrave（小金金）是一個只支援 macOS 14 Sonoma 以上的 Native menu-bar companion。它用一隻兩個月大的真實幼黃金，依照目前使用狀態走路、奔跑、玩耍、跳起來提醒，或在休息時安靜呼吸。

## 本機安裝

在有相容的 macOS Swift toolchain（完整 Xcode 或與 SDK 對應的 Command Line Tools）上：

```bash
bash Scripts/run-checks.sh
open dist/goldenrave.app
```

app 是 menu-bar-only utility，不會建立不必要的 Dock 視窗。第一次啟動後，點選 menu bar 的小黃金即可看到連續使用時間、今天累積時間、下次休息和控制按鈕。

## 下載已打包版本

從 GitHub repo 開啟 `Actions` → `macOS checks` → 最新一筆 `main` 分支且顯示成功的 workflow run，在頁面最下方 `Artifacts` 下載 `goldenrave-macOS-dmg`。解壓縮後打開 `goldenrave.dmg`，在跳出的視窗把小黃金拖到 Applications 再開啟。這個 artifact 是未上架 App Store 的個人版，使用 ad-hoc signing；如果 macOS 第一次顯示安全提示，請在 Finder 對 app 按右鍵並選「打開」。

## 發佈新版本

1. 把 `Packaging/Info.plist` 的 `CFBundleShortVersionString` 改成新版號（例如 `0.2.0`），合併進 `main`。
2. 在 `main` 打 tag 並推上去：`git tag v0.2.0 && git push origin v0.2.0`。
3. `Release` workflow 會檢查 tag 和版號一致、跑完全部測試，再建立 GitHub Release 並附上 `goldenrave.dmg`。
4. 已安裝的 app 會在啟動時、每天一次、以及打開設定時檢查最新 Release；有新版時，設定底部會出現「前往更新 x.y.z 版」，下面附更新步驟。

## 追蹤模式

- Private（預設）：只記錄 active／idle、連續使用時間、每日使用時間和休息事件。
- Detailed（明確 opt-in）：在你同意 Accessibility 後，才讀取前景 app；視窗標題和瀏覽器 URL 只有取得得到時才記錄。

任何模式都不記錄按鍵內容、滑鼠座標、截圖、剪貼簿、帳號，也沒有雲端同步或遙測。資料只留在本機 SwiftData store。設定中的 Detailed 說明會先告訴你用途和系統設定位置，不會在第一次啟動時偷偷要求權限。

## 休息提醒

預設每工作 45 分鐘休息 10 分鐘，可在「設定」調整工作與休息的分鐘數。休息前最多 5 分鐘小黃金會撲過來提醒你；可以開始休息、提早結束休息、暫停或恢復休息提醒，不會鎖定鍵盤或螢幕。

## 移除本機資料

在設定中按「清除本機資料」並確認即可刪除所有使用、詳細活動與休息紀錄。此專案沒有登入、帳號或遠端資料。
