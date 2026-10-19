# BeeCount 个人简约版

基于 TNT-Likely/BeeCount 的 `5484496` 提交，保留原项目 LICENSE、作者与版权信息。

## 本次实现

- 默认进入个人简约界面：明细、统计、记账按钮、我的。
- 浅灰背景、白色圆角卡片、淡黄色点缀，支持系统浅深色切换。
- 首页和统计使用同一条真实交易数据流；支持月份切换和账本切换。
- 汇总遵循原项目规则：转账不计收支，排除“不计收支”记录，外币使用已保存的本位币折算金额。
- 预算使用原仓储逻辑，保留“不计预算”规则与账本的自定义月份起始日。
- 保留现有的交易编辑器（收入、支出、转账、编辑删除）、账户、导入导出、应用锁及智能记账；二级页面沿用原布局，页头改为简洁背景。
- 关闭加入、邀请、成员管理与成员统计入口；相关路由降级到个人版提示，相关 provider 不发起请求，成员变更函数拒绝执行。
- 同步设置保留离线及备份选项，个人版隐藏 BeeCount Cloud 的配置标签。

未删除共享数据表与底层同步协议，避免破坏已有数据库兼容性。这是个人客户端能力限制，不是服务端权限系统；此版建议从全新个人安装开始使用。

## 验证状态（2026-10-19 更新）

已上传至 `yongbaowo/BeeCount` 的个人版分支，并在 GitHub macOS 云端完成验证：

- Flutter 3.27.3 依赖解析、代码生成与代码分析通过（保留原项目已有的非阻断警告）。
- `test/personal/personal_edition_test.dart` 的 7 项测试通过：收支规则、关闭共享请求、320/390 宽度浅深色导航、真实数据展示与月份切换；额外断言正文可见、导航栏高度和位置，覆盖首次真机发现的布局问题。
- [iOS 模拟器 Debug 构建成功](https://github.com/yongbaowo/BeeCount/actions/runs/39182457055)。
- [未签名 iPhone Release 构建、IPA 打包和 Artifact 上传成功](https://github.com/yongbaowo/BeeCount/actions/runs/39187814051)。
- 下载后核验了外层压缩包 SHA-256、内层 IPA 完整性、独立 Bundle ID、iPhoneOS 平台和 arm64 主程序。

首次云端代码分析因 agentcore 子模块测试依赖没有初始化而失败；补上该模块的 `dart pub get` 后，重跑通过。

用户已通过 Windows Sideloadly 完成首版签名安装。真机启动后发现导航栏占满页面、正文不可见：导航栏内的 Center 在 Scaffold 的宽松高度约束下扩展到了整屏。0.0.2 将导航内容高度限制为 64，并让首页测试与真实导航栏一起渲染，检查正文可点击、正文高度和导航位置。修复后仍需在同一手机上覆盖安装验收。

## 无 Mac、使用 Windows 安装

未签名 IPA 在 `personal/unsigned-ipa` 分支生成，主 App 的 Bundle ID 是 `io.github.yongbaowo.beecount.personal`。首个侧载包只包含主 App，不包含小组件扩展；源代码中的扩展保持保留。iCloud 与小组件所需权限仍需另行配置，建议先验证本地记账及导出备份。

当前修复版为 0.0.2（build 2）。升级时沿用首次签名的 Apple 账号及 Sideloadly 设置覆盖安装，不要先卸载旧版。

1. 在上方 Release 构建页面的 Artifacts 下载 `BeeCount-Personal-unsigned-IPA`，解压外层 ZIP，得到 `BeeCount-Personal-unsigned.ipa`。
2. 在 Windows 从 [Sideloadly 官网](https://sideloadly.io/) 获取工具，按官网要求准备 Apple 驱动组件。
3. 用数据线连接自己的 iPhone，在手机上完成系统要求的信任确认。
4. 将 IPA 放入 Sideloadly，用自己的 Apple 账号在本地签名安装，按工具和手机上的实际提示完成验证。
5. 按工具说明处理开发者模式、证书信任和续签。官网说明免费账号签名通常有效 7 天，可配置自动续签；是否能在当前手机上正常运行仍须实测。

云端构建没有使用 Apple 密码、签名证书或私钥。代码和构建配置分别在 [PR #1](https://github.com/yongbaowo/BeeCount/pull/1) 和 [PR #2](https://github.com/yongbaowo/BeeCount/pull/2) 留有草稿，尚未合并到 main。

## 在 Mac 上构建

使用项目原有的 Flutter 3.27.3，以及 Xcode、CocoaPods：

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test test/personal/personal_edition_test.dart
flutter build ios --simulator --debug --dart-define=BEECOUNT_PERSONAL=true
```

### 安装到自己的 iPhone

1. 先运行上述检查。模拟器构建成功不代表签名配置已完成。
2. 使用自己的 Bundle ID 与 Apple Team ID。项目包含原作者的 App Group、iCloud 与小组件标识，不能直接用它们签名。
3. 用配置脚本先预览，再实际修改（下面的 ID 是示例，须换成自己的）：

```bash
python3 scripts/configure_personal_ios.py --bundle-id com.yourname.beecountpersonal --team-id YOURTEAMID
python3 scripts/configure_personal_ios.py --bundle-id com.yourname.beecountpersonal --team-id YOURTEAMID --apply
open ios/Runner.xcworkspace
```

脚本同时调整 Runner、扩展、小组件 App Group、iCloud 容器、测试 ID 和 Dart App Group 调用，保留 debug 的 `.dev` 后缀。它不会登录账户、创建 Apple 后台标识或证书。

4. 在 Xcode 中为 Runner 和小组件扩展选择自己的团队；使用小组件与 iCloud 时，需要在自己的 Apple 开发者配置中启用相应能力和容器，必要时调整 entitlement/provisioning。能力不能签名时，先在 Xcode 中处理对应配置，不要将未签名产物当作可安装 IPA。
5. 连接 iPhone 后运行。当前代码与本说明均不含任何签名证书或已签名 IPA。

为了兼容现有快捷指令，本次仍保留 `beecount://` URL scheme。与 App Store 原版同时安装时，系统可能把快捷链接交给另一版本；可先只安装其中一个版本，或后续统一定制 URL scheme。

## 恢复原版界面

此 checkout 默认开启个人版；构建时传 `--dart-define=BEECOUNT_PERSONAL=false` 可恢复原界面和共享能力。iOS 标识配置脚本的修改是独立的，不会随该开关恢复。

## 许可

遵循仓库 LICENSE。免费非商业修改不等于无条件再分发；修改版本公开源码、保留版权与许可等要求仍然适用。修改源码已公开在用户的 GitHub Fork；未替用户进行商业授权。
