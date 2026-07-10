# BLEUnlock 工程开发与交付手册

## 1. 手册目标

本文是 BLEUnlock 仓库的开发、测试、Review、交付和发布准则。它既面向维护者，也面向在本仓库工作的 Agent。

核心原则只有一句：**任何“完成”都必须有与风险匹配的证据；构建成功不等于蓝牙、权限、锁屏和升级链路已经验证。**

本文中的路径均相对仓库根目录。执行任务时，用户的明确要求优先于本文；若用户限定“只分析”“不要提交”“不要推送”或“不要发布”，必须遵守该边界。

## 2. 项目事实与风险边界

BLEUnlock 是原生 macOS 菜单栏应用，使用 Swift、Objective-C 和 C，通过 CoreBluetooth 感知 BLE 设备距离，并与 AppKit、辅助功能、钥匙串、通知、Apple Events、登录项和系统锁屏能力交互。

- Xcode 工程：`BLEUnlock.xcodeproj`
- 共享 scheme：`BLEUnlock`
- 主应用 target：`BLEUnlock`
- 登录启动 helper target：`Launcher`
- 主 Bundle ID：`com.bifrost-proxy.BLEUnlock`
- Launcher Bundle ID：`com.bifrost-proxy.BLEUnlock.Launcher`
- 最低部署版本：macOS 10.13
- 正式主分支：`master`
- 正式发布入口：`.github/workflows/release.yml`
- 详细发版说明：`docs/RELEASING.md`

当前工程没有 XCTest Testables，`.github/workflows/test.yml` 的主要门禁是安装脚本检查和无签名 Xcode 构建。因此：

1. `xcodebuild build` 通过只能证明工程可编译，不能证明 BLE 和系统集成功能正确。
2. `xcodebuild test` 当前不会执行有效测试，禁止把它写成“单元测试通过”。
3. 涉及 BLE、权限、锁屏、睡眠唤醒、登录启动或后台运行的改动，必须补真实 Mac 场景验证。
4. 自动解锁会读取钥匙串密码并模拟输入，真实测试必须使用受控环境，绝不在日志、截图、提交或聊天中暴露密码。

## 3. 任务模式与权限边界

### 3.1 开发模式

用户要求实现、修复、重构或补齐能力时：分析真实代码路径，修改代码和必要文档，执行适用测试，并完成至少两轮 Review/Fix/Test。开发模式默认包含“本机验证与打包 -> 提交并推送 -> 创建或更新 PR -> 跟进 CI -> 失败修复并重新推送 -> CI 全绿”的完整闭环；除非用户明确要求仅保留本地改动、不要提交、不要推送或不要创建 PR，否则不得停在本地完成状态。

### 3.2 检查模式

用户明确要求只分析、只 review 或不要修改时：只允许读取文件、检查配置和运行安全的只读命令。不得编辑、提交、推送、创建 PR、打 tag 或发布。

### 3.3 文档模式

仅修改文档时：核对文档中的路径、命令和仓库现状，检查中英文内容是否一致。若文档改变了用户操作或发布流程，仍需按新流程做可执行验证。

### 3.4 发布模式

只有用户明确要求发布或明确授权打 tag 时才能进入。发布具有外部影响，禁止根据“把代码做完”“合并 PR”等普通开发请求自行推导发布权限。

### 3.5 Git 外部操作

开发模式默认交付到当前任务分支并通过 PR 合入 `master`；提交、推送、创建/更新 PR 和 CI 看护属于正常开发闭环。用户明确要求本地-only、不要提交、不要推送或不要 PR 时才跳过，并在最终交付中记录豁免和风险。任何情况下都不得擅自覆盖远端分支、移动公开 tag 或发布 Release；正式发布仍必须获得明确授权。

## 4. 每次任务的启动检查

### 4.1 Shell 初始化

本仓库中每次执行命令前必须先加载 zsh 配置。所有命令示例都遵守这一规则：

```sh
source ~/.zshrc
git status --short --branch
```

不要输出或记录 shell 配置中的 token、证书密码和其他 secret。

### 4.2 工作区和分支

任务开始先确认分支、工作区和最近提交：

```sh
source ~/.zshrc
git status --short --branch
git log -5 --oneline --decorate
```

- 工作区干净：可在用户指定的当前分支继续。
- 存在用户的既有改动：不得覆盖、回退、重排或顺手提交。
- 任务与既有改动无关且用户未要求留在当前目录：优先使用独立 worktree。
- 用户明确要求“当前分支”：保留当前分支，在不破坏既有改动的前提下工作；若无法安全隔离，再向用户说明阻塞。
- 禁止使用 `git reset --hard`、`git clean -fd`、`git checkout -- <file>` 等破坏性命令清理用户改动。

### 4.3 工具链预检

编译前先确认当前工具链。日常编译、启动和本地 DMG 验收只要求 Command Line Tools：

```sh
source ~/.zshrc
xcode-select -p
xcrun --sdk macosx --show-sdk-path
swiftc --version
```

涉及 XIB、Asset Catalog、Launcher helper、完整 Release 构建、签名或公证时，再确认完整 Xcode。若 `xcode-select -p` 指向 `/Library/Developer/CommandLineTools`，则不能运行 `xcodebuild`：

```sh
source ~/.zshrc
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

Xcode 位于其他目录时应调整 `DEVELOPER_DIR`，不要擅自全局执行 `sudo xcode-select --switch`。

## 5. 仓库地图

| 路径 | 职责 | 修改时重点 |
| --- | --- | --- |
| `BLEUnlock/AppDelegate.swift` | 应用生命周期、菜单、偏好、锁屏/解锁、钥匙串、通知、媒体控制、登录项、迁移 | 主线程、权限、密码安全、定时器、状态一致性 |
| `BLEUnlock/BLE.swift` | 扫描、连接、RSSI、设备聚合、UUID/MAC 映射、名称解析 | CoreBluetooth 状态机、睡眠恢复、并发回调、多设备逻辑 |
| `BLEUnlock/LEDeviceInfo.swift` | 只读查询系统 Bluetooth SQLite 数据库 | 数据库不可用、字段为空、系统版本差异 |
| `BLEUnlock/lowlevel.c`、`lowlevel.h` | 低层系统交互 | ABI、权限、macOS 兼容性 |
| `BLEUnlock/checkUpdate.swift` | GitHub Release 检查和待更新状态 | 版本比较、网络失败、DMG 资源缺失 |
| `BLEUnlock/AboutBox.swift` | About 窗口和外部链接 | URL 指向 `bifrost-proxy/BLEUnlock` |
| `Launcher/` | 旧系统登录启动 helper | Bundle 路径、重复启动、旧登录项迁移 |
| `BLEUnlock/Base.lproj/` | 基础 XIB 和默认本地化 | 菜单连接、控件 identifier、默认文案 |
| `BLEUnlock/*.lproj/` | 各语言字符串 | key 完整性、占位符和菜单含义一致 |
| `BLEUnlock/Info.plist` | 权限说明、版本、Bundle 元数据 | Bluetooth、Apple Events、最低系统版本 |
| `BLEUnlock/*.entitlements` | 系统能力声明 | 最小权限、签名后实际生效 |
| `BLEUnlock.xcodeproj/` | target、依赖、Build Settings、scheme | 文件是否加入 target、Debug/Release 一致 |
| `install.sh` | 下载、SHA-256 校验、DMG 安装和覆盖升级 | 临时目录、挂载清理、路径含空格、失败退出 |
| `scripts/build-local.sh` | 仅用 Command Line Tools 编译、隔离启动并打包本地 DMG | 不得替代正式 Xcode Release；必须保持隔离 Bundle ID 和安全偏好 |
| `scripts/profile-background.sh` | 后台稳态 CPU/RSS 性能门禁 | 必须绑定真实设备执行发布验收；普通进程自测不能冒充发布结果 |
| `.github/workflows/test.yml` | PR 和 master 的基础 CI | 安装脚本检查、无签名构建 |
| `.github/workflows/test-build.yml` | 手动 packaging smoke test | 固定从 `master` checkout，不代表当前分支通过 |
| `.github/workflows/release.yml` | tag 驱动的正式发布 | tag、Changelog、签名、公证、Release、Homebrew |
| `CHANGELOG.md`、`CHANGELOG.cn.md` | 英文和中文发布说明 | 版本标题严格一致 |
| `docs/RELEASING.md` | 发布操作手册 | 必须与 workflow 保持一致 |

`AppDelegate.swift` 和 `BLE.swift` 已经很大。新增非平凡逻辑时，应优先提取职责清晰、可测试的类型或文件，而不是继续堆叠；但不要为了“顺手整理”制造与任务无关的大规模重构。

## 6. 开发标准流程

### 第一阶段：目标和验证计划

在改代码前写清四类清单：

1. **必须实现**：用户能观察到的新行为或修复结果。
2. **必须不破坏**：相关旧功能、最低系统兼容性、偏好和迁移数据、安全边界。
3. **必须验证**：构建、脚本、真实 Mac 场景、失败路径。
4. **必须交付**：代码、测试记录、文档、本地 DMG 验收、提交、PR 和全绿 CI；用户明确豁免的动作必须记录原文和风险。

计划必须具体到文件、场景和命令。不要用“测试一下”“最后 review”代替可核验任务。

### 第二阶段：定位真实代码路径

修改前至少完成：

- 从 UI 入口追到状态持久化和系统副作用。
- 确认 Debug 与 Release 配置、主 App 与 Launcher 是否都受影响。
- 搜索旧 Bundle ID、UserDefaults key、钥匙串 service 和脚本目录的迁移逻辑。
- 检查对应 README、Changelog、XIB、本地化和 workflow。
- 对系统 API 确认最低 macOS 版本和 `#available` 降级路径。

### 第三阶段：最小实现

- 只修改实现目标所需文件，保留用户既有改动。
- AppKit UI 和菜单更新放在主线程；CoreBluetooth 和计时器回调要明确线程与生命周期。
- 新建 Timer、observer、BLE connection 或异步任务时，必须设计取消、失效和退出清理。
- 多设备逻辑同时考虑 `any` / `all`、零设备、设备暂时丢失、UUID 轮转和重复发现。
- 新系统 API 必须用 `#available` 保护，并保留 macOS 10.13 可编译的替代路径。
- 密码、钥匙串内容、token、证书、Apple app password 禁止写日志。
- 设备 MAC、UUID 和用户名属于敏感诊断信息；测试报告只保留定位所需的最小片段。
- 不得把自动解锁描述为强认证。BLE 广播可被仿冒，安全说明必须与 README 一致。

### 第四阶段：同步项目资源

改动命中以下情况时必须同步：

- 新增 Swift/ObjC/C 文件：确认加入正确 target 和 Build Phase。
- 新增菜单或用户文案：更新 `Base.lproj/Localizable.strings` 和 `zh-Hans.lproj/Localizable.strings`；其他语言要么同步翻译，要么明确采用默认英文回退。
- 修改 XIB：检查 outlet/action 连接，至少启动一次对应窗口或菜单。
- 修改权限或系统能力：同步 `Info.plist`、entitlements、README 权限说明和签名验证。
- 修改 Bundle ID、偏好 key、钥匙串 service、登录项或 event 脚本路径：提供向后迁移，不能让升级用户静默丢数据。
- 修改安装或发布：同步 `README.md`、`README.en.md`、`docs/RELEASING.md` 和 workflow。
- 面向下个版本的用户可感知改动：同时更新 `CHANGELOG.md` 与 `CHANGELOG.cn.md` 的 Unreleased 段落。

禁止提交 `.DS_Store`、`xcuserdata/`、本机 DerivedData、证书、keychain、DMG 临时挂载产物或包含真实密码的日志。

## 7. 测试策略

### 7.1 测试层级

| 层级 | 证明什么 | 不能证明什么 |
| --- | --- | --- |
| 静态检查 | Shell 语法、plist/Xcode 工程基本结构 | App 可运行、BLE 行为正确 |
| 无签名构建 | 当前 SDK 下 Debug/Release 可编译 | 权限、签名、公证、真实设备行为 |
| 自动化测试 | 可隔离的纯逻辑和回归断言 | 硬件 RSSI、系统锁屏、权限弹窗 |
| 真实场景测试 | 用户可感知的 BLE/macOS 集成行为 | 其他 macOS 和硬件组合全部可靠 |
| Release 验收 | DMG、更新、安装和发布渠道闭环 | 尚未覆盖的长期稳定性 |

### 7.2 最小静态检查

任何修改 `install.sh` 的任务至少执行：

```sh
source ~/.zshrc
bash -n install.sh
bash install.sh --help
```

修改 plist、entitlements 或 scheme 时执行对应解析检查：

```sh
source ~/.zshrc
plutil -lint BLEUnlock/Info.plist BLEUnlock/BLEUnlock.entitlements Launcher/Info.plist Launcher/Launcher.entitlements ExportOptions.plist
xmllint --noout BLEUnlock.xcodeproj/xcshareddata/xcschemes/BLEUnlock.xcscheme
```

### 7.3 本地构建

日常开发不必安装完整 Xcode。仓库提供基于 Command Line Tools 的隔离构建、启动和打包总门禁：

```sh
source ~/.zshrc
scripts/build-local.sh --verify
```

该命令使用 `clang + swiftc` 生成 `build/local-clt/BLEUnlockLocal.app`，采用独立 Bundle ID 和隔离 HOME，并禁用自动锁屏、自动解锁、开机启动和媒体控制。它会确认 App 稳定启动，生成 `BLEUnlockLocal.dmg` 与 SHA-256，校验镜像、只读挂载，并检查 Bundle ID、签名、可执行文件和 `/Applications` 链接。所有代码、脚本、Xcode 工程或运行时行为变更提交前都必须通过该门禁。

需要保持本地 App 运行进行手工验证时：

```sh
source ~/.zshrc
scripts/build-local.sh --run
```

CLT 链路生成的是本地 smoke-test DMG，不运行 Interface Builder 或 Asset Catalog 编译，也不包含完整 App 图标、Launcher helper、Developer ID 签名或公证。它不能冒充正式 Release 产物；涉及这些资源、Release 配置或正式发版时，仍必须使用完整 Xcode 和下方的 `xcodebuild` 流程。

#### 完整 Xcode 构建

与 CI 一致的基础门禁：

```sh
source ~/.zshrc
xcodebuild clean build \
  -project BLEUnlock.xcodeproj \
  -scheme BLEUnlock \
  CODE_SIGNING_ALLOWED=NO
```

发布相关或 Build Settings 变更，再补 Release 构建：

```sh
source ~/.zshrc
xcodebuild clean build \
  -project BLEUnlock.xcodeproj \
  -scheme BLEUnlock \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO
```

可选静态分析：

```sh
source ~/.zshrc
xcodebuild analyze \
  -project BLEUnlock.xcodeproj \
  -scheme BLEUnlock \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
```

若本机没有完整 Xcode、SDK 不兼容或签名条件缺失，必须记录原始阻塞；不得把“命令未运行”写成“通过”或“预计 CI 会通过”。

### 7.4 自动化测试建设

当前 scheme 没有测试 target。新增或修改可隔离的纯逻辑时，优先：

1. 将版本比较、设备聚合、阈值判断、迁移转换等逻辑从 AppKit/CoreBluetooth 副作用中拆出。
2. 建立或扩展 XCTest target，覆盖正常、边界和失败路径。
3. 确认 test target 加入共享 scheme 和 CI。

如果某项逻辑只能依赖真实硬件或 macOS 权限验证，必须在交付中说明为什么没有自动化，并用 `human_tests/` 真实用例补足，不能用空的 `xcodebuild test` 代替。

### 7.5 真实场景测试

任何运行时行为变更都应新增或更新 `human_tests/<feature>.md`；首次引入时创建 `human_tests/README.md` 作为索引。用例至少记录：

- 用例 ID 和目标；
- macOS 版本、Mac 型号、BLE 设备类型；
- 前置权限与偏好；
- 操作步骤；
- 可观察的预期结果；
- 实际结果和证据；
- 清理和恢复步骤。

仅文档改动且不改变用户操作、运行时行为或发布流程时，可以不新增 `human_tests/`，但必须完成文档自检并说明运行时测试不适用。

#### 真实测试安全红线

- 未经用户明确同意，不得自动锁定用户当前桌面、关闭显示器、模拟输入密码、重置蓝牙服务或修改系统权限。
- 优先使用专用 macOS 测试账号；开始前保存工作，关闭敏感窗口，准备手动恢复路径。
- 自动解锁测试优先使用测试密码和测试账号。禁止屏幕录制键盘输入或打印钥匙串内容。
- 测试结束后恢复自动解锁、开机启动、后台运行、媒体控制和 event 脚本设置。
- 不得通过放宽安全检查、删除断言或永久修改用户偏好来“让测试通过”。

#### 按影响面选择场景

| 修改范围 | 必须覆盖的真实场景 |
| --- | --- |
| 扫描/设备发现 | 蓝牙开/关、至少一台真实 BLE 设备、未配对设备、配对设备、设备消失再出现 |
| RSSI/距离判断 | 阈值两侧、抖动、无信号超时、延迟锁定、主动/被动模式 |
| 多设备 | 单设备、两设备、unlock any/all、lock any/all、其中一台丢失 |
| UUID/MAC/名称 | UUID 轮转或重启恢复、重复设备去重、MAC/名称回退、Option 详情显示 |
| 锁屏/解锁 | 手动锁屏、远离锁定、靠近解锁、错误密码、辅助功能未授权、钥匙串拒绝 |
| 睡眠/唤醒 | 显示器睡眠、系统睡眠、靠近唤醒、唤醒时不解锁、恢复扫描 |
| 菜单/后台运行 | 菜单反复开关、隐藏图标后仍监控、重新打开恢复图标、真正 Quit 后进程退出 |
| 登录启动 | macOS 13+ `SMAppService`、旧系统 Launcher 路径、重复注册、关闭后不再启动 |
| 通知/更新 | 通知授权允许/拒绝、自动/手动检查、无网、无 DMG、链接仓库正确 |
| 媒体/Event Script | Apple Events 允许/拒绝、away/lost/unlocked/intruded 参数、失败不阻塞锁屏 |
| 升级迁移 | 旧 Bundle ID 偏好、钥匙串、登录项、Application Scripts 迁移且不重复 |
| 本地化/XIB | 默认语言、简体中文、菜单宽度、快捷键、深浅色、About 窗口 |

诊断时可观察统一日志：

```sh
source ~/.zshrc
log stream --style compact --predicate 'process == "BLEUnlock"'
```

名称解析日志位于 `~/Library/Logs/BLEUnlock/name-resolution.log`。分享前必须脱敏 MAC、UUID、用户名和其他设备标识。

## 8. Review/Fix/Test 闭环

代码或运行时行为变更至少完成两轮独立闭环；仅文档且不改变流程时至少完成一轮。

### 第 1 轮：实现后自查

1. 重读用户目标和验证计划，逐项标记已满足、未满足、未验证。
2. 执行 `git status --short`、`git diff`，有暂存内容时再执行 `git diff --cached`。
3. Review 功能、安全、线程、定时器、迁移、最低系统版本、本地化和缺失测试。
4. 修复发现的问题。
5. 运行与修改范围直接相关的最小测试，并记录结果。

```sh
source ~/.zshrc
git status --short
git diff --check
git diff
```

### 第 2 轮：修复后复查

1. 基于最新 diff 再次核对用户目标和第 1 轮问题。
2. 再次检查未跟踪、已暂存和未暂存文件，确认没有混入用户改动或本机产物。
3. 复查第 1 轮修复是否引入回归，代码、README、Changelog、XIB、本地化、测试记录是否一致。
4. 复跑受影响测试；第 1 轮失败过的路径必须明确复跑。
5. 若仍发现阻塞问题，继续第 3 轮及后续循环，直到关闭。

测试失败必须先归因：产品缺陷、测试缺陷、环境/权限问题、需求或文档不一致。禁止为了绿灯直接删除用例、降低断言或隐藏错误。

## 9. 变更范围与最小验证矩阵

| 修改范围 | 最小验证 |
| --- | --- |
| 仅 Markdown | `git diff --check`；核对相对链接、命令和中英文一致性；若改变开发/测试/发布流程，执行 `scripts/build-local.sh --verify` |
| Swift/ObjC/C | `scripts/build-local.sh --verify`；相关真实场景；适用的 XCTest |
| Xcode 工程/Build Settings | Debug + Release build；检查两个 target 和产物元数据 |
| plist/entitlements/权限 | `plutil -lint`；build；真实权限允许/拒绝路径；签名后验证（若适用） |
| XIB/本地化 | build；启动 App；相关语言和菜单/窗口实测 |
| `install.sh` | `bash -n`、`--help`、临时目录端到端安装、失败清理 |
| CI workflow | YAML/脚本 review；对应 workflow 实际运行；检查触发分支/tag |
| 发布链路 | Release build、tag/Changelog 校验、DMG、checksum、Release、Homebrew、干净机验收 |

CI 通过后仍要确认它实际运行了与本次改动相关的 job。路径过滤、手动 workflow、从 `master` 固定 checkout 的构建都不能替代当前分支验证。

## 10. 提交、PR 与 CI

### 10.1 提交前

- 两轮 Review/Fix/Test 已完成。
- `scripts/build-local.sh --verify` 已完成本机编译、启动烟测、DMG/checksum 和挂载验收。
- 其他适用本地测试通过，未执行项有明确原因和风险。
- `git diff --check` 无空白错误。
- 没有 `.DS_Store`、`xcuserdata`、build、DMG、证书、日志或 secret。
- 用户可感知变更已同步 README/Changelog/本地化/测试记录。
- 提交只包含本任务文件。

### 10.2 PR

正常开发必须通过任务分支 PR 合入 `master`。本地门禁通过后立即提交、推送并创建或更新 PR；除非用户明确豁免，缺少 PR 的开发任务不得标记完成。PR 说明至少包含：

1. 目标与背景；
2. 实现摘要；
3. 风险和兼容性；
4. 自动验证命令与结果；
5. 真实设备/权限测试环境与结果；
6. 未验证项及原因；
7. 截图或日志需要脱敏。

### 10.3 CI 看护

推送并创建/更新 PR 后，必须跟进 `.github/workflows/test.yml` 到结束。失败时读取失败 step 和日志，进入“归因 -> 修复 -> `scripts/build-local.sh --verify` -> 提交推送 -> 重新看护”循环，直到所有 required 和非-required checks 均为 `pass` 或 `skipping`。不得因等待时间长、第一次失败或本地已通过而提前宣布完成。

若使用 GitHub CLI：

```sh
source ~/.zshrc
gh pr checks --watch --fail-fast
```

若 fail-fast 返回失败，先用 `gh run view <run-id> --log-failed` 获取失败日志，修复后重新执行本地总门禁并推送，再次看护新 run。最终必须再执行一次不带 fail-fast 的 `gh pr checks --watch`，确认整个 PR 全绿。

不要只报告“CI 红了”；要报告 PR URL、run id、workflow、job、失败 step、关键错误、修复提交和最终全绿证据。权限不足、GitHub 故障或 runner 不可用属于阻塞，必须给出可核验信息，不能写成完成。

## 11. 正式发布

正式流程以 `docs/RELEASING.md` 和 `.github/workflows/release.yml` 为准。本文给出发布门禁，不复制 workflow 的实现细节。

### 11.1 发布前提

- 用户明确授权发布版本号。
- 发布提交已经通过 PR 合入最新 `master`。
- 工作区干净，`master` 与 `origin/master` 一致。
- 版本符合 `X.Y.Z`，tag 符合 `vX.Y.Z`。
- `CHANGELOG.md` 和 `CHANGELOG.cn.md` 都存在精确的 `## X.Y.Z` 标题，内容一致且无残留 Unreleased 条目遗漏。
- `.github/workflows/test.yml` 在 tag 对应提交上通过。
- `TAP_PUSH_TOKEN` 已配置；否则 Homebrew 更新会失败，不能宣称发布完成。
- 若声明“已签名/已公证”，必须确认全部签名和 Apple 凭据已配置并验证成功；缺少凭据时产物是未签名或未公证版本。

### 11.2 打 tag

禁止从功能分支、脏工作区或未合入提交直接发布：

```sh
source ~/.zshrc
git switch master
git pull --ff-only origin master
git status --short --branch
git tag -a vX.Y.Z -m "BLEUnlock vX.Y.Z"
git push origin vX.Y.Z
```

tag 推送会触发 `.github/workflows/release.yml`，依次校验元数据、构建、按配置签名和公证、打包 DMG、生成 SHA-256、创建 GitHub Release 并更新 Homebrew Cask。

`workflow_dispatch` 只用于重跑已经存在的 tag。不得把它当成从任意分支临时发布的入口。

### 11.3 旧脚本和 Test Build 的边界

- 根目录 `release` 是历史发布脚本，不是当前 Bifrost Proxy 正式发布入口。除非维护者明确要求修复或考古，不要执行它。
- `.github/workflows/test-build.yml` 固定 checkout `master`，且包含固定的 smoke-test 版本号。它只用于验证 master 的打包能力，不能证明当前功能分支或目标发布版本已经验证。

### 11.4 发布验收

Release workflow 全绿后，在没有本地开发产物的 Mac 上验证：

- GitHub Release 同时存在 `BLEUnlock-vX.Y.Z.dmg` 和 `.sha256`。
- checksum 可以通过，DMG 可挂载，App 可复制到 `/Applications` 并启动。
- Bundle ID 为 `com.bifrost-proxy.BLEUnlock`，App 版本为 `X.Y.Z`。
- 若本次发布承诺签名/公证，`codesign`、Gatekeeper 和 stapling 验证全部通过。
- `brew install --cask bifrost-proxy/tap/unlock` 安装的版本和 SHA 与 Latest Release 一致。
- `install.sh` 能完成下载、checksum 校验、覆盖安装和启动。
- App 内更新检查、About 链接和通知点击都指向 `bifrost-proxy/BLEUnlock`。
- 从旧 Bundle ID 升级时，偏好、钥匙串、登录项和 event 脚本迁移符合预期。
- 权限重新授权和未签名版本的 Gatekeeper 限制已在发布说明中准确告知用户。

### 11.5 失败与回滚

- Release 成功、Homebrew 失败：修复 tap 权限或 token 后重跑同一个 tag。
- 构建或元数据失败：修复代码后发布新的 patch 版本；不要移动已经公开的 tag。
- 严重问题：取消 Latest、按需要标记 pre-release，并将 Homebrew Cask 回退到上一个已验证版本。
- 回滚也是外部写操作，必须有用户授权和可核验记录。

## 12. 完成定义（Definition of Done）

只有以下条件满足，任务才可标记为完成：

- 用户目标逐项完成，或明确列出阻塞和风险。
- 真实代码路径已核对，不是只根据 README 推测。
- 代码、Xcode 工程、plist/entitlements、XIB、本地化、README、Changelog、workflow 和测试记录在适用范围内一致。
- 代码或运行时行为变更完成至少两轮 Review/Fix/Test；文档-only 变更完成至少一轮。
- 所有适用测试真实执行并通过；未执行和不适用项有具体原因。
- 本机 `scripts/build-local.sh --verify` 已完成编译、隔离启动、DMG/checksum 和挂载验收。
- 自动构建证据与真实 BLE/macOS 场景证据分开记录，没有把空 TestAction 当作测试通过。
- 未触碰或混入用户既有改动，没有残留本机产物和敏感信息。
- 除非用户明确豁免远端交付：变更已提交并推送，PR 已创建或更新，全部 CI checks 已结束且全绿；commit、PR URL 和 run id 可核验。
- 若已授权发布：tag、Release workflow、DMG/checksum、Homebrew 和安装验收全部可核验；任一环节失败都不能称为发布完成。

## 13. 最终交付模板

最终回复按实际范围简洁覆盖：

1. **目标对齐**：完成了什么，哪些未完成。
2. **变更范围**：修改文件和未触碰的既有改动。
3. **Review 闭环**：每轮发现、修复和复测结果。
4. **验证矩阵**：命令/场景、结果、未执行原因。
5. **Git/PR/CI**：分支、commit、PR、run 和状态（若适用）。
6. **发布状态**：tag、Release、签名/公证、Homebrew、安装验收（仅发布任务）。
7. **残余风险**：没有则明确写“未发现阻塞残余风险”。

禁止使用“应该没问题”“理论上可用”“测试通过”这类没有范围和证据的结论。
