# BLEUnlock 发版流程

## 仓库分工

- `bifrost-proxy/BLEUnlock`：产品主仓库，`master`、版本 tag、GitHub Release、安装脚本都以这里为准。
- `Skyearn/BLEUnlock`：当前 GitHub fork parent，只作为上游变更来源之一，不再承载 Bifrost Proxy 的发布。
- `ts1/BLEUnlock`：原始项目，用于保留来源和许可证归属。
- `bifrost-proxy/homebrew-tap`：Homebrew Tap，只保存 `Casks/unlock.rb`，由 Release 工作流自动更新。

应用 Bundle ID 是 `com.bifrost-proxy.BLEUnlock`，旧版的 `com.github.Skyearn.BLEUnlock` 和 `jp.sone.BLEUnlock` 只保留在迁移代码中。

## 一次性准备

1. 在 `bifrost-proxy` 下创建公开仓库 `homebrew-tap`，默认分支为 `main`。
2. 创建一个只能写入 `bifrost-proxy/homebrew-tap` Contents 的 fine-grained GitHub token。
3. 在 `bifrost-proxy/BLEUnlock` 的 Actions secrets 中保存为 `TAP_PUSH_TOKEN`。
4. 如需 Developer ID 签名和公证，再配置以下 secrets：
   - `MACOS_CERT_P12_BASE64`
   - `MACOS_CERT_PASSWORD`
   - `KEYCHAIN_PASSWORD`
   - `MACOS_SIGNING_IDENTITY`
   - `APPLE_ID`
   - `APPLE_TEAM_ID`
   - `APPLE_APP_PASSWORD`

没有签名相关 secrets 时仍可构建 Release，流水线会自动使用 ad-hoc 签名，并逐个签署内部 Mach-O、Launcher 和外层 App，再从 DMG 只读挂载后执行 `codesign --verify --deep --strict`。这可以避免未签名或签名不一致导致的“应用已损坏”，但 ad-hoc 签名不等于 Developer ID 信任，`spctl` 仍会拒绝它；要让 Homebrew 和普通下载用户稳定无拦截安装，必须配置 Developer ID 并完成 Apple 公证。`TAP_PUSH_TOKEN` 是正式发版的必需项；缺失时工作流会明确失败，不会把 Homebrew 未更新伪装成发版完成。

## 日常开发和上游同步

不要直接把上游分支合进发布 tag。统一走下面的分支和 PR 流程：

```sh
git remote add upstream https://github.com/Skyearn/BLEUnlock.git # 只需执行一次
git fetch upstream
git switch -c sync/upstream-YYYYMMDD origin/master
git merge --no-ff upstream/master
# 解决冲突并跑 CI 后，向 bifrost-proxy/BLEUnlock:master 提 PR
```

如果只挑选部分上游修复，在独立分支 `cherry-pick`，同样通过 PR 合入 `master`。Bifrost Proxy 自己的改动也先合入 `master`，tag 永远只打在已经通过 CI 的 `master` 提交上。

## 正式发版

1. 确定下一个语义化版本，例如 `1.15.0`。
2. 同步更新 `CHANGELOG.md` 和 `CHANGELOG.cn.md`，两个文件都添加精确的 `## 1.15.0` 标题。
3. 提 PR，等待 CI 构建通过并合入 `master`。
4. 在最新 `master` 上创建 annotated tag 并推送：

```sh
git switch master
git pull --ff-only origin master
git tag -a v1.15.0 -m "BLEUnlock v1.15.0"
git push origin v1.15.0
```

5. `.github/workflows/release.yml` 自动执行：
   - 校验 tag 格式和 Changelog；
   - 将 tag 版本写入 App，构建并检查 Bundle ID；
   - 始终签名并校验 App：有证书时使用 Developer ID，否则使用 ad-hoc；
   - 从生成的 DMG 只读挂载 App，再次校验所有 Mach-O 和 Bundle ID；
   - 在配置 Developer ID 与公证凭据时提交公证、staple 并执行 Gatekeeper 验收；
   - 生成 `BLEUnlock-vX.Y.Z.dmg` 和 `.sha256`；
   - 创建或更新 `bifrost-proxy/BLEUnlock` GitHub Release；
   - 更新 `bifrost-proxy/homebrew-tap` 的 `Casks/unlock.rb`。

`workflow_dispatch` 只用于重跑一个已经存在的 tag，不用于从任意分支临时发版。

## 发版验收

GitHub Actions 全绿之后，在一台没有本地开发产物的 Mac 上验证：

```sh
brew uninstall --cask unlock 2>/dev/null || true
brew untap bifrost-proxy/tap 2>/dev/null || true
brew install --cask bifrost-proxy/tap/unlock
```

再验证脚本安装：

```sh
curl -fsSL https://raw.githubusercontent.com/bifrost-proxy/BLEUnlock/master/install.sh | bash
```

最终检查：

- `/Applications/BLEUnlock.app` 可以启动；
- `mdls -name kMDItemCFBundleIdentifier /Applications/BLEUnlock.app` 显示 `com.bifrost-proxy.BLEUnlock`；
- App 内“检查更新”和通知点击都打开 `bifrost-proxy/BLEUnlock`；
- Homebrew 安装的版本与 GitHub Latest Release 一致；
- 旧版升级时，设置、钥匙串密码和 event 脚本按预期迁移；
- 用户知道新 Bundle ID 会触发蓝牙、辅助功能、通知等权限重新授权。
- 从已安装旧版本执行“更新”→“检查更新…”，能够检测到更高版本，点击“安装更新”后自动替换 App、重启并显示新版本号。

绑定至少一台设备并启用后台运行后，再执行 60 秒性能门禁：

```sh
source ~/.zshrc
scripts/profile-background.sh "$(pgrep -x BLEUnlock | head -1)" 60
```

必须同时满足平均 CPU 低于 10%、最大常驻内存低于 80 MB，才可继续发布。

## 用户安装命令

Homebrew 不支持 npm 的 scope 语法，因此不能使用 `brew install @bifrost-proxy/unlock`。对外固定使用：

```sh
brew install --cask bifrost-proxy/tap/unlock
```

或者：

```sh
curl -fsSL https://raw.githubusercontent.com/bifrost-proxy/BLEUnlock/master/install.sh | bash
```

## 失败和回滚

- GitHub Release 成功但 Homebrew 更新失败：先修复 `homebrew-tap` 权限或 `TAP_PUSH_TOKEN`，再用 Actions 手动重跑同一个 tag；Release 上传和 Cask 生成都是幂等的。
- 构建或元数据校验失败：修复代码并发布新 patch 版本；不要移动已经公开的 tag。
- 版本存在严重问题：在 GitHub Release 标记为 pre-release 或删除 Latest 标记，并将 `Casks/unlock.rb` 回退到上一个已验证版本。已经公开的 tag 不重写。
