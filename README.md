# Golden Retriever

Golden Retriever 是一個只支援 macOS 14 Sonoma 以上的 Native menu-bar companion。它用一隻兩個月大的真實幼黃金，依照目前使用狀態走路、奔跑、玩耍、跳起來提醒，或在休息時安靜呼吸。

## 本機安裝

在有相容的 macOS Swift toolchain（完整 Xcode 或與 SDK 對應的 Command Line Tools）上：

```bash
bash Scripts/run-checks.sh
open dist/GoldenRetriever.app
```

app 是 menu-bar-only utility，不會建立不必要的 Dock 視窗。第一次啟動後，點選 menu bar 的小黃金即可看到連續使用時間、今天累積時間、下次休息和控制按鈕。

## 追蹤模式

- Private（預設）：只記錄 active／idle、連續使用時間、每日使用時間和休息事件。
- Detailed（明確 opt-in）：在你同意 Accessibility 後，才讀取前景 app；視窗標題和瀏覽器 URL 只有取得得到時才記錄。

任何模式都不記錄按鍵內容、滑鼠座標、截圖、剪貼簿、帳號，也沒有雲端同步或遙測。資料只留在本機 SwiftData store。設定中的 Detailed 說明會先告訴你用途和系統設定位置，不會在第一次啟動時偷偷要求權限。

## 休息提醒

預設每工作 45 分鐘提醒一次，提前 5 分鐘讓小黃金跳起來，休息預設 10 分鐘。提醒可以開始休息、延後 10 分鐘、暫停提醒，通知不會鎖定鍵盤或螢幕。

## 移除本機資料

在設定中按「清除本機資料」並確認即可刪除所有使用、詳細活動與休息紀錄。此專案沒有登入、帳號或遠端資料。
