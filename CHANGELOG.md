# Release Notes

## 1.14.3

- **Fix:** RSSI median filter increased from 3 to 5 samples — signal display is even smoother with single outliers fully suppressed.
- **Fix:** Launch-at-login no longer hangs the app on enable.
- **Fix:** Device list expansion no longer freezes in edge cases (e.g. rapid open).
- **Fix:** Duplicate device entries properly cleaned when UUIDs rotate, preventing stale entries from accumulation.
- **Fix:** Device submenu no longer reopens unexpectedly after closing the parent menu.
- **Fix:** Submenu width properly resets after Option-key detail mode.

- **Style:** MAC-resolved devices shown in standard text, unresolved UUID-only devices in gray — clearer at-a-glance distinction, especially in dark mode.

<details>
<summary>中文发布说明</summary>

- **修复:** RSSI 中值滤波由 3 样本提升至 5 样本 — 信号显示更平滑，偶发异常值完全抑制。
- **修复:** 设置开机启动不再导致应用未响应。
- **修复:** 设备列表展开不再偶发卡顿（如快速展开时）。
- **修复:** UUID 轮转时旧条目正确清理，不再累积重复设备。
- **修复:** 关闭父菜单后设备子菜单不再异常重新弹出。
- **修复:** Option 展开详情后子菜单宽度正确收束。

- **样式:** 已解析 MAC 地址的设备以标准字色显示，未解析的纯 UUID 设备以灰色显示 — 一目了然，深色模式下区分更明显。

</details>

## 1.14.2

- **Fix:** RSSI signal display is more stable — switched from 5-sample moving average to median-of-3 filter. Single outliers are completely eliminated, while real signal changes track with lower latency.
- **Fix:** When a monitored device's Bluetooth UUID rotates (privacy feature), the app now correctly detects and inherits the new UUID in real time. Previously it could get stuck showing 'Not Detected' until restart.
- **Fix:** Screen lock no longer stops background scanning — UUID rotations and proximity detection continue working as long as any device is monitored.
- **Fix:** RSSI 0 dBm no longer appears — treated as disconnected.
- **Fix:** Separator and 'Scanning…' now work correctly in all cases: when unmonitored devices arrive, when the first device is checked during menu tracking, and when no devices are checked.
- **Fix:** MAC resolution no longer fails when a device broadcasts both classic Bluetooth and BLE with the same name (e.g. RedMagic) — prefers the classic entry.
- **Fix:** Device detection count (e.g. '1/2') is accurate immediately on menu open.
- **Fix:** Monitored device list order no longer flickers during scans.

- **Feat:** Hold ⌥ (Option) to show full MAC address and UUID — default menu displays device name and RSSI only.
- **Feat:** UUID-only devices show collapsed `XXXX…YYYY` format for readability.
- **Feat:** Clickable "Pair to stabilize random address tracking →" hint opens Bluetooth settings.
- **Feat:** ⌥ indicator on "Device List" main menu item.
<details>
<summary>中文发布说明</summary>

- **修复:** RSSI 信号显示更稳定 — 由 5 样本均值平滑改为中值滤波（3 样本取中位数）。偶发异常值被完全消除，真实信号变化响应延迟更低。
- **修复:** 已监控设备的蓝牙 UUID 轮转（隐私特性）后，应用现在能实时识别并继承新 UUID。之前可能卡在「未检测到信息」直到重启。
- **修复:** 屏幕锁定不再中断后台扫描 — 只要存在已监控设备，UUID 轮转和距离检测持续运行。
- **修复:** RSSI 0 dBm 不再出现，统一视为断连。
- **修复:** 分隔线和「扫描中…」在所有场景下正确显示：未勾选设备到达时、菜单追踪期间勾选首个设备时、以及无已勾选设备时。
- **修复:** 设备同时广播经典蓝牙和 BLE 且同名时（如 RedMagic）MAC 解析失败 — 优先选经典蓝牙条目。
- **修复:** 打开菜单时设备检测计数（如 '1/2'）即时准确。
- **修复:** 已勾选设备列表不再因扫描而频繁跳动。
- **新增:** 按住 ⌥ 显示完整 MAC 地址和 UUID — 默认仅显示设备名和 RSSI。
- **新增:** 无名称设备显示折叠 UUID `XXXX…YYYY`。
- **新增:** 可点击提示「配对以稳定追踪随机地址 →」打开蓝牙设置。
- **新增:** 主菜单「设备列表」⌥ 提示。

</details>
## 1.14.1

- Resolve MAC addresses from system paired Bluetooth devices via IOBluetooth and display them in the device list.
- Automatically remap device tracking when BLE UUID changes after disconnect or reboot, using MAC-based cross-correlation. No reconfiguration needed.
- Monitored devices are now sorted to the top of the device list, with unmonitored devices following in discovery order.
- Add Bluetooth entitlement for broader macOS compatibility.
- Fix MAC persistence: changed from `{UUID → MAC}` to `{MAC → UUID}` format with merge-on-write, preventing MAC entries from being overwritten when BLE correlation runs concurrently.
- Ensure monitored devices always appear in the runtime device dictionary, so MAC-based correlation can match rotated BLE UUIDs after app restart.
- Fix device menu not refreshing unmonitored devices after quick reopen caused by aggressive stale-device cleanup.
- Fix group separator line not appearing on first launch.
- Improve menu stability during tracking: defer full menu rebuilds while the menu is open, updating only separator visibility in real time.
- Fall back to macOS Bluetooth LE database for MAC address resolution when IOBluetooth name lookup fails.

<details>
<summary>中文发布说明</summary>

- 通过 IOBluetooth 从系统已配对蓝牙设备中获取 MAC 地址，并显示在设备列表中。
- 当设备 BLE UUID 因断连或系统重启发生变化时，自动通过 MAC 地址交叉关联重映射追踪，无需手动重新配置。
- 已勾选的监控设备自动排序到设备列表顶部，未勾选设备按发现顺序排列在下方。
- 添加 Bluetooth entitlement 以兼容更多 macOS 版本。
- 修复 MAC 持久化：改为 `{MAC → UUID}` 格式并合并写入，避免并发 BLE 关联时覆盖已有 MAC 映射。
- 确保监控设备始终出现在运行时设备字典中，使重启后 MAC 交叉关联能匹配已轮换的 BLE UUID。
- 修复快速重开菜单时未勾选设备不刷新的问题，将过期设备清理延迟到菜单关闭时执行。
- 修复首次启动时已勾选/未勾选设备间分割线不出现的问题。
- 改进菜单追踪期间的稳定性：菜单打开期间仅更新分割线可见性，推迟完整重建。
- IOBluetooth 名称查找失败时，回退到 macOS 蓝牙 LE 数据库解析 MAC 地址。

</details>

## 1.14.0

- Resolve MAC addresses from system paired Bluetooth devices via IOBluetooth and display them in the device list.
- Automatically remap device tracking when BLE UUID changes after disconnect or reboot, using MAC-based cross-correlation. No reconfiguration needed.
- Monitored devices are now sorted to the top of the device list, with unmonitored devices following in discovery order.
- Add Bluetooth entitlement for broader macOS compatibility.

<details>
<summary>中文发布说明</summary>

- 通过 IOBluetooth 从系统已配对蓝牙设备中获取 MAC 地址，并显示在设备列表中。
- 当设备 BLE UUID 因断连或系统重启发生变化时，自动通过 MAC 地址交叉关联重映射追踪，无需手动重新配置。
- 已勾选的监控设备自动排序到设备列表顶部，未勾选设备按发现顺序排列在下方。
- 添加 Bluetooth entitlement 以兼容更多 macOS 版本。

</details>

## 1.13.6

- Add an Updates submenu with automatic update checks and manual update actions.
- Let manual update checks open the latest DMG download directly, with a fallback to the release page.
- Show pending update status in the menu even when notifications are disabled.
- Make automatic update notifications silent to reduce interruptions.
- Move BLE name-resolution logs into the current user's Library/Logs directory.
- Harden password handling, timer lifecycle, manual-lock recovery, and media pause state synchronization.
- Fix iBeacon prefix parsing and improve launcher path validation.
- Migrate the app bundle identifier to `com.github.Skyearn.BLEUnlock` with compatibility for legacy settings, Keychain data, and login items.

<details>
<summary>中文发布说明</summary>

- 新增"更新"子菜单，整合自动检查更新与手动检查更新入口。
- 手动检查更新时可直接下载最新 DMG，若没有 DMG 资源则回退到发布页。
- 即使未开启系统通知，也会在菜单中显示新版本状态提示。
- 自动检查更新通知改为静默提示，减少对当前工作的打断。
- BLE 设备名称解析日志改为写入当前用户的 `~/Library/Logs/BLEUnlock/`。
- 加强密码读取、定时器生命周期、手动锁定恢复逻辑，以及媒体暂停状态的线程安全。
- 修复 iBeacon 前缀识别问题，并改进 Launcher 对主程序路径的定位与校验。
- 将应用 Bundle ID 迁移为 `com.github.Skyearn.BLEUnlock`，并兼容旧版本的配置、钥匙串密码与登录项迁移。

</details>

## 1.13.5

- Improve media pause handling when locking the Mac.
- Enhance lock-triggered automation timing when playback is controlled by a remote device.
- Improve stale-update state handing so incorrectly cached states are automatically cleared after an app upgrade or reinstall.
- Update the secure password retrieval to cover BLE-unlock-specific access failures without blocking other keychain operations.

<details>
<summary>中文发布说明</summary>

- 改善锁屏时对媒体暂停的处理逻辑。
- 优化远程设备控制播放时锁定触发自动化的时机。
- 改进版本更新状态的持久化处理，应用升级或覆盖安装后自动清理旧的缓存状态。
- 更新安全密码读取逻辑，覆盖 BLE 解锁专属的访问失败路径而不阻塞其他钥匙串操作。

</details>

## 1.13.4

- Reorganized the unlock and lock controls by grouping logic and RSSI settings into `Unlock Settings` and `Lock Settings` submenus.
- Disable the logic choices when only one device is being monitored, and refresh that state immediately after device selections change.
- Keep monitored devices in the name-resolution path even when their RSSI temporarily drops below the scan list threshold, reducing UUID fallback for devices such as Apple Watch.
- Updated the README files to match the revised menu structure and installation notes for this fork.

<details>
<summary>中文发布说明</summary>

- 将解锁与锁定相关选项重新整理为 `解锁设置` 和 `锁定设置` 子菜单，把逻辑选择与 RSSI 阈值放到同一处。
- 当只监控一台设备时，自动禁用逻辑选择项，并在勾选设备变化后立即刷新菜单状态。
- 对已监控设备，即使瞬时 RSSI 低于扫描列表门槛，也继续参与名称解析，减少 Apple Watch 这类设备回退显示为 UUID 的情况。
- 同步更新了 README，反映新的菜单结构以及此 fork 的安装说明。

</details>

## 1.13.3

- Reorganized the unlock and lock controls by grouping logic and RSSI settings into `Unlock Settings` and `Lock Settings` submenus.
- Disable the logic choices when only one device is being monitored, and refresh that state immediately after device selections change.
- Keep monitored devices in the name-resolution path even when their RSSI temporarily drops below the scan list threshold, reducing UUID fallback for devices such as Apple Watch.
- Updated the README files to match the revised menu structure and installation notes for this fork.

<details>
<summary>中文发布说明</summary>

- 将解锁与锁定相关选项重新整理为 `解锁设置` 和 `锁定设置` 子菜单，把逻辑选择与 RSSI 阈值放到同一处。
- 当只监控一台设备时，自动禁用逻辑选择项，并在勾选设备变化后立即刷新菜单状态。
- 对已监控设备，即使瞬时 RSSI 低于扫描列表门槛，也继续参与名称解析，减少 Apple Watch 这类设备回退显示为 UUID 的情况。
- 同步更新了 README，反映新的菜单结构以及此 fork 的安装说明。

</details>

## 1.13.2

- Reduced BLE scan, connection, and RSSI polling activity during the system sleep transition to lower the chance of the Mac waking immediately after being put to sleep.
- Resume BLE monitoring automatically after the system wakes, while keeping normal proximity detection and unlock behavior intact.
- Preserved wake-on-proximity behavior for display sleep without letting the app keep aggressively probing devices at the system sleep boundary.

<details>
<summary>中文发布说明</summary>

- 收紧了系统进入睡眠前后的 BLE 扫描、连接与 RSSI 轮询行为，降低 Mac 刚睡下去就被再次唤醒的概率。
- 在系统唤醒后自动恢复 BLE 监控，同时保持正常的设备检测与解锁流程。
- 保留了显示器休眠场景下的靠近唤醒能力，但避免应用在整机睡眠边界继续激进探测设备。

</details>

## 1.13.1

- Reduced aggressive display wake retries around sleep/wake transitions to avoid getting stuck in a half-wake display state.
- Added automatic recovery after required permissions are granted, so BLEUnlock can resume work without forcing an app restart.
- Fixed temporary mismatches between the menu bar summary and the monitored device list when scan cache entries expire.
- Refined the monitored-device summary text to show the detected count and strongest RSSI more clearly.

<details>
<summary>中文发布说明</summary>

- 收紧了睡眠/唤醒边界上的亮屏重试逻辑，避免显示器卡在"被唤醒但没有真正点亮"的半唤醒状态。
- 在授予所需权限后新增了自动恢复流程，避免应用陷入"必须重启才能恢复"的循环。
- 修复了扫描缓存过期时，菜单栏摘要与受监控设备列表短暂显示不一致的问题。
- 优化了受监控设备的摘要文案，更直观地显示已检测设备数量和当前最强 RSSI。

</details>

## 1.13.0

- Added support for monitoring multiple BLE devices at the same time, with configurable unlock and lock logic.
- Improved wake-from-sleep unlock reliability by waiting for the lock screen to become ready before sending the password, and retrying when the first attempt lands too early.
- Simplified the menu bar summary into a single status line that shows the number of selected devices, how many are currently detected, and the strongest monitored signal.
- Unified RSSI display between the summary line and the monitored devices in the device list so the values are easier to understand.
- Restored live updates in the device scan list while keeping monitored-but-currently-undetected devices visible.
- Added a Simplified Chinese README and linked it from the English documentation.

<details>
<summary>中文发布说明</summary>

- 新增了同时监控多台 BLE 设备的支持，并可分别配置解锁逻辑与锁定逻辑。
- 改进了从睡眠唤醒后的自动解锁可靠性：现在会等待锁屏界面准备就绪，并在首次输入密码时机过早的情况下自动重试。
- 简化了菜单栏摘要，改为用单行状态显示已选设备数、当前已检测到的设备数，以及当前最强的监控信号。
- 统一了菜单摘要与设备列表中的 RSSI 显示方式，让信号强度数值更容易理解。
- 恢复了设备扫描列表的实时更新，同时保留了"已设为监控但当前未检测到"的设备显示。
- 新增了简体中文 README，并在英文文档中加入了链接。

</details>
