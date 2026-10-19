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

## 验证状态

当前交付环境没有 Flutter/Dart SDK 和 Xcode，无法运行 Flutter analyzer、单元/组件测试、模拟器构建或真机安装。已进行 Dart 语法解析、源码相对导入检查、变更检查，以及 iOS 配置脚本的本地验证。这些检查不能替代编译与运行测试。

新增 `test/personal/personal_edition_test.dart` 覆盖收支规则、无云连接的共享功能关闭、320/390 宽度浅深色导航、真实数据展示及月份切换，尚待 Flutter 环境运行。

新增手动工作流 `Personal iOS check`：获取依赖、代码生成、分析、测试、构建 iOS 模拟器应用。未上传到 GitHub、未触发运行，不会发布或签名。

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

遵循仓库 LICENSE。免费非商业修改不等于无条件再分发；修改版本公开源码、保留版权与许可等要求仍然适用。本次未发布仓库，也未替用户进行商业授权。
