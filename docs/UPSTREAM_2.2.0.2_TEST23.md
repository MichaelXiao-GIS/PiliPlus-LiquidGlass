# PiliPlus 2.2.0.2 同步与 iOS 状态栏回顶

日期：2026-11-07。状态：源码同步及状态栏回顶修复已通过 293 项组件/工具测试；静态分析无 error/warning（39 项已有 info）。iOS 27.2 构建和模拟器检查进行中。

## 版本与来源

| 项目 | 值 |
| --- | --- |
| 原定制基线 | test22，`cfacaed843457c95fb6238ed60487b4c9ab7d670` |
| 原上游基线 | 2.2.0，`265f879fa85973b4bf885bde2562f1007f1013b8` |
| 本次上游目标 | 2.2.0.2，`d9e9626f1a3f89cd9ca85e18f61aaba02634e12a` |
| 上游范围 | 18 个提交，35 个变更文件 |
| 待构建应用版本 | `2.2.0+23`；上游标签为四段版本，但沿用上游 pubspec 的三段应用版本 |
| Flutter 基线 | 3.47.9，未改动 |
| 已发布版本 | 仍为 test22 |

通过 GitHub 连接读取上游完整 compare 的 35 个文件补丁，在已确认内容完整的工作区执行 `git apply --check` 后应用。原有定制没有出现补丁冲突。此次为工作区源码同步，未生成 Git 合并提交；当前 HEAD 仍是 test22。将来正式合并/提交时应保留本记录中的上游 SHA，不能将旧 HEAD 当作新构建的完整来源。

## 上游更新与适配

- 选集面板、选集定位及番剧缓存入口更新。
- 评论分页与游标处理修复，避免部分视频评论加载不全；保留自定义评论操作菜单。
- 课堂视频与可空番剧季列表处理；评论时间戳验证改进。
- 动态/专栏内容、封面、文字对齐及投票链接处理更新。
- 弹幕跳转增加提前量；匿名账号 buvid 获取与请求签名修复。
- 投屏切换到上游指定的 dlna-dart Git 依赖，锁定解析结果；同步其他上游依赖更新。
- 继承上游 macOS 标题栏/拖动、Linux MPRIS、Android 音量与 ChromeOS 方向处理。
- 简介新增 BV/AV 编号在本分支使用 `Wrap`，保留点击复制并允许窄栏、大字号换行。

30 个不与既有定制重叠的文件已逐个计算 Git blob hash，与上游目标文件的 SHA 一致。剩余 5 个文件保留本分支改动：`lib/main.dart`、`lib/pages/video/introduction/ugc/view.dart`、`lib/pages/video/reply/widgets/reply_item_grpc.dart`、`lib/plugin/pl_player/utils/fullscreen.dart`、`pubspec.yaml`。已检查其中的新旧改动共存；这不是运行时验证。

## 状态栏回顶修复

根因：主界面使用 `MainLayout` 自定义布局，首页/动态的纵向列表拥有各自控制器；没有实现 Flutter 3.47.9 转发的原生 `handleStatusBarTap`。动态内部 Scaffold 还设置了 `primary: false`，不能依靠默认主滚动控制器恢复此行为。

新增主界面监听组件 `glass_status_bar_scroll_to_top.dart`。现有 `GlassScrollBody` 登记当前选中且仍挂载的纵向 `ScrollPosition`，事件发生时按当前主导航读取。无需更换业务滚动控制器，也不增加覆盖顶区的手势层；Duo 侧置状态区沿用同一系统事件。

行为约束：

- 只将当前可见列表滚到 `minScrollExtent`；不调用刷新，不重置隐藏分类或横向 UP 列表。
- 与 Flutter 原生 Scaffold 的回顶动作相同，使用 1000ms `Curves.easeOutCirc`；减少动态效果时直接定位。
- 主导航动画、被详情/弹窗覆盖、交互返回、drawer/sheet 的本地历史条目、应用非活动状态下不滚动背后的列表。
- 页面销毁时移除监听与目标；未挂载或没有纵向目标时忽略事件。
- 回顶滚动仍驱动已有玻璃顶区/底栏展开，不重建原生玻璃平台视图。

新增 `test/liquid_glass/status_bar_scroll_to_top_test.dart`，共 6 项测试（顶部和侧置状态区各一项，加 4 项交互/状态测试），通过 `tester.simulateStatusBarTap()` 驱动实际框架事件。测试范围包含主导航/分类选择、横向列表、无刷新、遮挡/返回、生命周期、减少动态效果与销毁。

## 已完成与未完成的验证

已完成：

- 上游版本与提交核对；完整补丁适用性检查及应用。
- 30 个文件与上游 blob SHA 精确比对；5 个重叠文件的定制保留检查。
- Git diff 空白检查；依赖 YAML 与变更范围核对。
- 只按 Git 索引恢复了迁移造成的 1700 个受管文件可执行位差异，没有改写它们的内容。

复工后已恢复项目专用 Flutter 3.47.9 / Dart 3.13.7、上游 Flutter/Material/Cupertino 和 GetX 补丁，并重新解析锁定依赖。2026-11-07 本机重新运行 293 项组件/工具测试全部通过，静态分析无 error/warning（39 项已有 info）。原环境缺失与下载错误已解决。iOS 构建和模拟器结果见文末发布验证记录；实体 iPhone 登录、播放、投屏及画中画尚未验收。

## 恢复环境后的检查

先按照 `PROJECT_RESTART_NOTES_2026-11-07.md` 恢复项目专用 Flutter 3.47.9、上游 Flutter/Material/Cupertino 补丁及 CocoaPods。不要把全部补丁重复应用到已修改的共享 SDK；设备 Geetest 与 arm64 模拟器的配置应分别准备。

```sh
dart tool/patch_ios_navigation.dart
flutter analyze --no-pub
flutter test --no-pub test/liquid_glass/status_bar_scroll_to_top_test.dart
flutter test --no-pub test/liquid_glass test/utils
flutter build ios --simulator --debug --no-pub -t lib/main.dart
```

模拟器/真机需检查：首页各分类及分区子分类、动态各分类，滚动后点击系统状态栏；切换分类后原偏移保留；点击顶区不会触发刷新；动态横向 UP 列表不复位；Duo 内外屏及旋转；打开详情/菜单及停住或取消返回；大字号/减少动态效果；上游评论分页、选集、字幕、课堂播放和投屏。

正式打包前重新生成 `pili_release.json`（迁移目录中的旧文件仍描述 test22），写入实际新提交与构建时间，显式使用应用版本 2.2.0、构建号 23，再生成 IPA、SHA256SUMS 与 build-info。`build-info` 只记录本次真正执行过的验证。此时再更新 README 的下载版本；当前 Release 链接保持 test22。

参考：[上游完整比较](https://github.com/bggRGjQaUbCoE/PiliPlus/compare/2.2.0...2.2.0.2)、[上游 Release](https://github.com/bggRGjQaUbCoE/PiliPlus/releases/tag/2.2.0.2)、[Flutter 3.47.9 状态栏事件](https://github.com/flutter/flutter/blob/3.47.9/packages/flutter/lib/src/widgets/binding.dart)、[Flutter Scaffold 回顶实现](https://github.com/flutter/flutter/blob/3.47.9/packages/flutter/lib/src/material/scaffold.dart)。
