# Release Notes

## 1.14.2

- **Fix:** RSSI signal display is more stable — switched from 5-sample moving average to median-of-3 filter. Single outliers are completely eliminated, while real signal changes track with lower latency.
- **Fix:** Device detection count (e.g. '1/2') is now accurate immediately when opening the menu, no longer requires expanding the device list.
- **Fix:** When a monitored device's Bluetooth UUID rotates (privacy feature), the app now correctly detects and inherits the new UUID in real time. Previously it could get stuck showing 'Not Detected' until restart.
- **Fix:** RSSI 0 dBm no longer appears — treated as disconnected.
- Remove name-based MAC resolution — startup uses persisted mapping and system Bluetooth cache only.
- Fix separator and 'Scanning…' disappearing when unmonitored devices arrived while the menu was open.
- Fix monitored device list order flickering during scans.

<details>
<summary>中文发布说明</summary>

- **修复:** RSSI 信号显示更稳定 — 由 5 样本均值平滑改为中值滤波（3 样本取中位数）。偶发异常值被完全消除，真实信号变化响应延迟更低。
- **修复:** 打开菜单时设备检测计数（如 '1/2'）即时准确，无需展开设备列表。
- **修复:** 已监控设备的蓝牙 UUID 轮转（隐私特性）后，应用现在能实时识别并继承新 UUID。之前可能卡在「未检测到信息」直到重启。
- **修复:** RSSI 0 dBm 不再出现，统一视为断连。
- 移除基于设备名的 MAC 解析 — 启动仅使用持久化记录和系统蓝牙缓存。
- 修复菜单打开期间新设备出现时分隔线和「扫描中…」消失的问题。
- 修复扫描时已勾选设备列表排序抖动。

</details>