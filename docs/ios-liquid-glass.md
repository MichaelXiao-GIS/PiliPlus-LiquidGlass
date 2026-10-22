# iOS Liquid Glass 适配

这份改动在 PiliPlus 的 Flutter 业务界面上接入 iOS 原生玻璃材质，并调整导航、内容和操作区的层级。Liquid Glass 从 iOS 26 开始提供，在 iOS 27 上继续使用系统实现。

## 界面变化

- 首页：大标题、悬浮搜索框、胶囊式分类导航。
- 主导航：原生玻璃底栏、SF Symbols、选中状态和动态未读角标；保留用户配置的导航顺序和重复点击行为。
- 宽窗口：以 700pt 可用宽度为界切换底栏和侧栏，支持横屏与可调整大小的窗口；用户明确选择侧栏时沿用该设置。
- 动态：分类导航和独立发布按钮。
- 我的：资料库标题、玻璃操作区；账号、无痕模式、主题等操作收进更多菜单。
- 搜索、设置、收藏等使用 `SimpleScaffold` 的页面，以及多选工具栏：统一悬浮页面栏。
- 设置入口：iOS 分组列表、彩色图标、详情指示箭头及账号操作分组。
- 全屏播放器：深色玻璃控制区，保留播放、弹幕和进度控制逻辑。
- 共用主题：中性内容背景、圆角面板、较大的触控区域。视频封面、动态正文和内容卡片仍作为内容层呈现。

材质只用于导航和操作层，遵循 Apple 的 [Materials 指引](https://developer.apple.com/design/human-interface-guidelines/materials)。适配窗口宽度和系统设置的依据见 [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) 及 [Modernize your UIKit app（WWDC26）](https://developer.apple.com/videos/play/wwdc2026/278/)。

## 实现

`ios/Runner/LiquidGlassPlugin.swift` 通过 Flutter Platform Views 提供 `UIGlassEffect(.regular)` 和原生导航按钮。Flutter 继续负责页面路由、内容、账号与播放状态。系统版本经过能力查询后才启用原生材质；iOS 15–25 使用 Flutter 模糊材质作为兼容样式。Android 和桌面端沿用原有界面分支。

共用组件位于 `lib/common/widgets/liquid_glass/`，iOS 主题位于 `lib/utils/ios/ios_theme.dart`。没有新增第三方 Flutter 依赖。项目继续使用 CocoaPods，避免现有插件混用 Swift Package Manager 时发生模块缺失。

辅助功能包括：系统字体大小乘以应用字号倍率、VoiceOver 标签及选中状态、至少 44pt 的主要导航触控区，以及对“减少透明度”“增强对比度”“减少动态效果”的响应。切换辅助功能设置或返回应用时会刷新原生状态。

## 构建与检查

使用项目指定的 Flutter 3.47.7。原生玻璃代码需要带 iOS 26 或更新 SDK 的 Xcode；验证 iOS 27 时使用 Xcode 27。最低部署版本对齐 Flutter 3.47 的要求，更新为 iOS 15。

本项目上游依赖 Flutter、Material 和 Cupertino 的补丁。干净环境请沿用仓库 `lib/scripts/patch.ps1 iOS` 的准备过程，或运行现有 `.github/workflows/ios.yml` 工作流。不要在同一套 SDK、包缓存或源码上重复应用补丁。

准备依赖后：

```sh
flutter analyze --no-pub
flutter test --no-pub test/liquid_glass/navigation_test.dart test/utils
flutter build ios --simulator --debug --no-pub
```

本次新增 14 项界面测试，覆盖点击、重复点击、未读语义、320/390/700pt 宽度、1/2/3 倍字体、安全区域、增强对比度和辅助功能设置刷新。连同现有工具测试，共 26 项通过。全项目静态分析无错误和警告，有 41 条原有 info 提示；新增原生桥接通过 iOS 14 最低部署目标的 Swift 类型检查。使用 Xcode 27.1 成功编译完整 iOS 模拟器应用，并在 iPhone 18 Pro / iOS 27.0 上检查了首页、原生底栏点击、搜索与键盘、资料库、分组设置、深色主题切换及首页独立的 VoiceOver 搜索标签。

若源码位于会自动附加 Finder 属性的桌面同步目录，iOS 框架签名可能报告 `resource fork, Finder information, or similar detritus not allowed`。将源码副本放在本地非同步目录构建即可；本次完整构建在临时目录完成。

发布前仍需在真机确认滚动时的原生合成性能、全屏视频、画中画和登录流程。组件测试不会替代这些设备检查。
