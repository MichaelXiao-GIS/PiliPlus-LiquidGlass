# PiliPlus Liquid Glass 复工记录

核对日期：2026-11-07。依据迁移目录中的源码、Git 索引和引用、开发文档、构建元数据、截图，以及当天读取的 GitHub 仓库与 Release 信息。

本轮完成项目交接核对；未修改应用源码、应用依赖补丁、安装开发工具、运行 Flutter 测试、重新构建 IPA 或向 GitHub 推送。本文件为新增交接记录。

## 1. 当前可接续的基线

| 项目 | 已核对结果 |
| --- | --- |
| 当前应用版本 | `2.2.0+22` |
| 最新本分支 Release | `v2.2.0-liquid-glass.test22`，2026-11-01 发布 |
| 当前本地分支 | `codex/upstream-2.2.0` |
| 本地 HEAD 与 GitHub main | 均为 `cfacaed843457c95fb6238ed60487b4c9ab7d670` |
| Git 索引对应 tree | `27a7f99c4d0871eec2a3aff96ca2bcd383948888`，与 GitHub HEAD tree 完全一致 |
| 已合并上游 | `2.2.0`，提交 `265f879fa85973b4bf885bde2562f1007f1013b8` |
| 初期改造基线 | PiliPlus 2.1.6；test1–test21 为该应用版本的迭代 |
| 正式入口 | `lib/main.dart` |
| 工具链记录 | Flutter 3.47.9；Dart SDK 约束 `>=3.13.0`；原发布使用 Xcode 27.1 / iOS 27.1 SDK |
| 部署目标 | iOS 15.0；原生玻璃按 iOS 26+ 能力启用；Duo 新 API 按 iOS 27.1+ 分支启用 |
| 应用标识 | 已发布 IPA 为 `com.example.piliplus` |
| 当前上游最新 Release | 核对当天为 `2.2.0.2`，2026-11-03 发布，尚未合入本分支 |

远程名称必须注意：`origin` 指向上游 `bggRGjQaUbCoE/PiliPlus`；`personal` 才指向 `MichaelXiao-GIS/PiliPlus-LiquidGlass`。当前 checkout 并非本地 `main`；本地 `ios-liquid-glass` 仍指向 test21。下一次开发应从已核对的 test22 HEAD 建立工作分支，不能仅凭分支名字选择起点。

## 2. Purpose：此前工作的目标

在保留 PiliPlus Flutter 业务、路由、账号和媒体播放能力的基础上，为 iOS 增加系统 Liquid Glass 材质、滚动联动导航和适应当前窗口的布局。项目重点包括首页与搜索、底栏/侧栏、设置、详情页转场和播放器，以及 iPhone Duo 内外屏、旋转、折叠与摄像头区域的适配。

实现边界：玻璃主要用于导航和操作层，视频封面、正文和信息卡片保留内容层；业务仍由 Flutter 管理，Swift/UIKit 提供原生材质、导航交互和窗口信息。Android、macOS、Windows、Linux 源码继承上游，不能因它们存在于仓库就认为已有相同程度的定制或回归验证。

## 3. Input：输入与依据

| 输入 | 在项目中的作用 |
| --- | --- |
| 上游 PiliPlus 2.1.6，后合并 2.2.0 | 视频、番剧、直播、动态、评论、账号、收藏、缓存等业务及跨平台框架 |
| Apple 设计/API 文档链接 | 原生材质、控件层级、窗口适配和 Duo 布局的设计依据；链接保存在 `ios-liquid-glass.md` |
| 使用反馈、问题截图与模拟器对照 | 驱动搜索动效、侧栏轴线、播放器安全区、返回白条/轮廓穿透、评论菜单等迭代 |
| `dist/test18/search-motion-reference.png` 与 `design-qa.md` | 用户选定的“柔弧归位”搜索框动效及其视觉验收依据 |
| `pubspec.yaml`、`pubspec.lock`、`.fvmrc` | 应用/工具链版本与依赖解析基线 |
| `lib/scripts/` 补丁 | 上游 Flutter、Material、Cupertino 与 iOS 构建准备，加上本分支 GetX 导航补丁 |
| `test/` 和 `tool/preview_*.dart` | 布局、状态、交互回归及脱离线上账号数据的原生合成复现 |

已有文档中的 Apple API 与设计说明用于还原实施依据；本轮重点核对其在源码中的使用，没有重新进行完整的 Apple 设计规范审计。

## 4. Process：实现结构与关键约束

### Flutter 与 UIKit 的分工

`GlassPlatformScope` 使用 `piliplus/liquid_glass` MethodChannel 获取原生能力、辅助功能和当前视图窗口几何信息。`LiquidGlassPlugin.swift` 注册 `piliplus/glass_surface` 与 `piliplus/glass_navigation` Platform Views，使用 `UIGlassEffect(.regular)` 提供背景，使用 `.clear` 提供滑动选择镜片；选择事件回传 Flutter，继续执行原业务行为。

`GlassWindowGeometry` 保存当前窗口尺寸、scale、size class、safe area、status bar frame、`verticalBarEdge` 和保留区域。Swift 读取当前 Flutter 视图的活动 `.division` / `.occlusion` 区域；Flutter 转换为折叠/遮挡特征。布局依据当前窗口，而非机型名称或固定内外屏分辨率。旋转期间拒绝与当前尺寸不匹配的旧几何信息，并处理应用缩放和局部视口坐标。

主页面在导航切换时保留内容子树、分类和滚动状态。控件避开折叠/摄像头区域，信息流可继续跨越显示区域。设置按至少 600pt 的可用宽度切换双栏。此实现不启用多个独立应用窗口。

### 已完成的界面行为

| 范围 | 当前实现 |
| --- | --- |
| 首页 | 大标题、悬浮搜索胶囊、分类导航、随滚动增强的顶区模糊；搜索连续缩窄并沿柔弧上移 |
| 滚动导航 | 居中底栏在页面顶部显示图标和文字，滚动后收为图标；不同页面/分类保留各自状态 |
| 导航手势 | 横向底栏和纵向侧栏均支持滑动镜片、释放吸附和延后提交；保留点击、重复点击、排序、角标行为 |
| Duo 侧栏 | 按系统物理边缘放置 60pt 紧凑胶囊；上方账号/搜索操作与下方导航分组，避让摄像头和折叠区域 |
| 设置与通用页栏 | iOS 分组设置、彩色图标、统一玻璃页栏、深浅色主题和 Cupertino 默认过渡 |
| 播放器 | 标题/快捷操作/底部进度区分组，居中控制栏，CC 字幕入口和分组更多菜单；处理非全屏返回按钮、详情分栏及状态区 |
| 评论 | 主评论与子评论长按共用居中浮层，单一拖动横杠，处理对称留白、大字号及摄像头避让 |
| 辅助功能 | 系统字号与应用倍率、VoiceOver、主要导航至少 44pt 触控区域、减少动态效果/透明度、增强对比度 |

### 转场合成的当前处理方式

这部分经历过多轮修复，更新时需要保留两种不同策略：

- 通用 `GlassSurface`：路由移动、交互返回停留或取消期间，切换为 Flutter 模糊材质；交互正文维持挂载。
- 主导航 `GlassNavigationBar`：保留 UIKit 平台视图及材质实例。test21 在被新页面覆盖及返回期间保留已渲染外观快照，暂停实时玻璃折射，解决胶囊轮廓穿透前景页面；恢复后继续收拢/展开。快照仅在内存，不保存屏幕图片。

不要把导航统一退回早期的 Flutter 备用材质策略，否则可能重新引入返回时发白的问题。

### 迭代脉络

| 阶段 | 主要工作 |
| --- | --- |
| test1–test5 | 原生材质桥接、页面栏、搜索收拢、滚动底栏、字体/裁切/触控区修复 |
| test6–test10 | Duo 当前窗口与保留区域、横屏视频详情分栏、紧凑侧栏、轮廓间距与底部内容延伸 |
| test11–test12 | 动态详情标题、交互返回合成、横向滑动镜片、底栏原生视图保留和播放状态区协调 |
| test13–test15 | 播放控件分组、字幕/摄像头避让、纵向侧栏手势、保留页面状态与横屏导航空间 |
| test16–test18 | 搜索弹簧运动及中途反向、更多菜单分组、用户选定的连续柔弧运动与逐帧验收 |
| test19–test21 | 侧栏与摄像头中轴对齐、评论菜单居中、导航玻璃轮廓穿透修复 |
| test22 | 合并上游 2.2.0 并保留上述适配，补充直播分类置顶与玻璃页头下的停靠行为 |

文档包含历史段落：test3 的 72pt 侧栏已被后续 60pt 方案替代；test11“侧栏不增加滑动选择”已被 test14 后的实现替代。README 的展示截图仍是 test18，不能用截图版本推断当前源码或发布版本。

## 5. 复工代码入口

以下路径相对仓库根目录。

| 下次改动 | 优先查看 |
| --- | --- |
| 原生玻璃、手势、合成快照 | `ios/Runner/LiquidGlassPlugin.swift`、`ios/Runner/AppDelegate.swift` |
| 窗口信息与平台能力 | `lib/common/widgets/liquid_glass/glass_platform.dart`、`glass_window_geometry.dart` |
| 底栏/侧栏、滚动联动 | 同目录 `glass_navigation_bar.dart`、`glass_navigation_rail.dart`、`glass_scroll_chrome.dart`、`glass_tab_scrubber.dart`；`lib/pages/main/view.dart` |
| 首页搜索 | `lib/pages/home/widgets/ios_home_header.dart`、`ios_home_header_motion.dart`；`lib/pages/home/view.dart` |
| 转场与材质降级 | `glass_route_transition.dart`、`glass_surface.dart`；`lib/scripts/get/ios_navigation.patch`、`tool/patch_ios_navigation.dart` |
| 主题、设置、通用页栏 | `lib/utils/ios/ios_theme.dart`、`lib/utils/theme_utils.dart`、`lib/pages/setting/view.dart`、`lib/common/widgets/scaffold/simple_scaffold.dart` |
| 播放器 | `lib/plugin/pl_player/widgets/glass_player_controls.dart`、`player_more_sheet.dart`、`lib/plugin/pl_player/view/view.dart` |
| 视频布局与系统栏 | `lib/pages/video/widgets/video_detail_layout.dart`、`video_detail_tabs.dart`、`video_status_bar_scope.dart`；`lib/plugin/pl_player/utils/system_bar_visibility.dart`、`fullscreen.dart` |
| 评论菜单 | `lib/pages/video/reply/widgets/reply_action_sheet.dart`、`reply_item_grpc.dart` |
| 测试与预览 | `test/liquid_glass/`、`test/utils/`；`tool/preview_dynamic_detail.dart`、`preview_tab_scrubber.dart`、`preview_reply_actions.dart`、`preview_navigation_occlusion.dart` |

## 6. Output：已有产物与验证证据

1. 完整 Flutter 多平台仓库，iOS 定制相对上游 2.2.0 的 GitHub compare 共涉及 112 个路径（包含源码、文档、测试和图片增删，不能全计为功能文件）。
2. `dist/` 根目录的初版产物，以及 `dist/test2/` 至 `dist/test22/` 的逐版构建记录；另有设计参考、模拟器截图、对照图及部分录屏。
3. test22 IPA、`SHA256SUMS.txt`、`build-info.json`、`release-notes.md`；GitHub Release 包含前三项附件。
4. 17 个 Liquid Glass 测试文件、4 个工具测试文件和 4 个独立预览入口。正式发布必须使用 `lib/main.dart`。
5. 中文/英文 README、开发说明、安装说明，以及 test18 专项设计验收记录。

test22 本地 IPA 已在本轮重新计算 SHA-256，与 GitHub Release 附件 digest 及本地 build-info 一致：

```text
文件：PiliPlus-LiquidGlass-2.2.0-test22-ios-arm64.ipa
大小：25178647 bytes
SHA-256：ce0252d1a8789d18f0f5c853927db9ad33edc5bb9bea0552d874d76966c7f899
```

实际读取 IPA 内 Info.plist 确认为版本 2.2.0、构建号 22、最低 iOS 15.0、iphoneos27.1 SDK、arm64。build-info 与 SHA256SUMS 文件本身也与 GitHub 附件 digest 一致。

原 test22 build-info 记录：287 项 widget/utility 测试通过；静态分析无 error/warning，保留 39 项已有 info lint；完成 arm64 Release 构建，并检查普通 iPhone 首页/直播分类置顶与 Duo 首页/侧栏布局。真机构建含原生 Geetest，模拟器因第三方插件排除 arm64 simulator 而使用上游 WebView 验证码方案。

这些是上次构建留下的验证记录，本轮没有重新执行。原生滚动性能、真实登录/验证码、播放/全屏、画中画等仍需在新构建和真实设备上检查，不能由组件测试或静态截图代替。

## 7. 迁移后的环境检查

| 检查 | 结果及复工影响 |
| --- | --- |
| 源码内容与提交 | 读取 Git index v2 并验证索引校验和；1700 个受管文件逐个计算 Git blob hash，全部与 index 一致；根据 index 重建 tree hash，与 GitHub HEAD 一致；无未合并的 index entries |
| 文件权限 | index 中 1700 个文件均为 `100644`，迁移后的这 1700 个文件均带可执行位；`core.filemode=true`，恢复 Git 后可能出现全仓库 mode-only 差异。不能把这些当成业务修改提交 |
| 系统 Git / Xcode | `/usr/bin/git` 被 Xcode 许可证未确认阻止；需要用户在 Xcode 或终端自行阅读并完成许可确认。本轮未接受许可 |
| 当前 Xcode | 应用 bundle 版本 27.2；目录含 iPhoneOS27.2 / iPhoneSimulator27.2 SDK。尚未以 `xcodebuild` 验证工具链或模拟器运行能力 |
| Flutter / Dart / FVM / CocoaPods / PowerShell | 当前 PATH 未发现 `flutter`、`dart`、`fvm`、`pod`、`pwsh`；这不等同于证明整台机器所有位置均未安装 |
| 包配置 | `.dart_tool/package_config.json` 有 253 个包条目；其中 252 个绝对 file URI 指向不存在的位置 |
| 旧路径 | `Generated.xcconfig`、`flutter_export_environment.sh` 和 Android 本地配置仍引用 `/private/tmp/piliplus-flutter-3.47.9`；应用路径仍为旧用户名 `/Users/michaelhsiao/...`，当前为 `/Users/michaelxiao/...` |
| 缓存与构建结果 | 旧临时 SDK、`/private/tmp/piliplus-test22-pub-cache` 已不存在；迁移的缓存与生成配置不能直接作为新机器可用环境 |

以上内容核对提供了“源码和发布产物未发现内容漂移”的证据，但不等于成功运行过 `git status`，也不等于这台 Mac 已能构建。

权限修复应仅按索引恢复受管文件的可执行位，并单独验证；不要对目录或整个 `dist/` 做笼统 chmod。当前未更改这些权限。

## 8. 构建恢复中的关键事项

- 固定 Flutter 3.47.9 并使用项目专用 SDK/依赖环境。上游会修改 Flutter SDK、`material_ui` 和 `cupertino_ui`，普通 `flutter pub get` 不足以复现构建，也不应把这套补丁混入其他项目的共享 SDK。
- 沿用 CocoaPods；原配置关闭 iOS/macOS Swift Package Manager。恢复依赖后再生成本机配置和 Pods，保留现有发布包与验收证据。
- `lib/scripts/patch.ps1 iOS` 依赖 `FLUTTER_ROOT` 和 `GITHUB_WORKSPACE`，并会修改当前项目的 iOS 手势/Geetest 文件与 SDK/包缓存。它不是可随意重复执行的幂等脚本，应在干净的构建副本上准备。
- 脚本对 Material/Cupertino 缓存的查找使用 `~/.pub-cache`；若继续使用独立 `PUB_CACHE`，必须先使路径选择与实际解析位置一致，不能仅设置环境变量就假定原脚本支持它。
- `tool/patch_ios_navigation.dart` 单独读取解析后的 GetX 路径，已打补丁会跳过，不兼容时会报错。每次依赖解析改变后应检查此步骤。
- 设备 Release 与 arm64 模拟器的 Geetest 准备不同，应保留 test22 的两条验证路径，避免通过删掉设备验证码功能来换取模拟器可编译。
- `lib/scripts/build.ps1` 会用 Git 提交总数重写构建号，不直接沿用本分支 test22/test23 序号。发布前需明确自有 test 编号，并同步 pubspec、构建参数、`pili_release.json`、build-info 和 Release。
- 迁移的 `Generated.xcconfig` 中构建号为 1，但真实已发布 IPA 为 22；应以 IPA 与发布元数据为准，重建时显式校验构建号。
- 如再次遇到 Finder 扩展属性导致签名报 `resource fork ... not allowed`，既有记录使用非同步的本地构建副本解决；不要因此删除 `dist/` 历史证据。

完成工具安装、许可确认、依赖和补丁准备后，基线检查命令为：

```sh
dart tool/patch_ios_navigation.dart
flutter analyze --no-pub
flutter test --no-pub test/liquid_glass test/utils
flutter build ios --simulator --debug --no-pub -t lib/main.dart
```

设备构建另行使用 iOS 真机补丁环境、正确的发布元数据和显式版本/构建号；IPA 打包及重新签名流程见 `ios-testing.md` 和现有 iOS workflow。本轮未生成或上传新包。

## 9. 下一次更新的建议顺序

1. 恢复 Xcode/Git 使用条件，处理 mode-only 差异，重新检查分支和远程；从 test22 的 HEAD 创建工作分支。
2. 恢复专用 Flutter 3.47.9 环境及补丁，重新解析依赖/生成本机路径；先重跑 test22 基线检查，再开展功能改动。
3. 将上游 2.2.0.2 作为可评估的维护更新。GitHub compare 显示相对 2.2.0 有 18 个提交、35 个文件变化；本轮只读取比较，没有执行合并。
4. 按实际需求确定新功能或修复范围；若合并上游，重点复核下表的重叠文件，重叠不代表已经发生冲突。
5. 运行相关组件/工具测试、静态分析、普通 iPhone 与 Duo 模拟器检查；之后以真机验证登录、播放、字幕、旋转、画中画和滚动性能。
6. 明确版本号与 test23 或后续构建号，更新说明和截图，生成 IPA、SHA256SUMS、build-info，核对包内版本/标识后再按发布任务处理上传。

| 2.2.0 → 2.2.0.2 与定制分支重叠的文件 | 需要保护的行为 |
| --- | --- |
| `lib/main.dart` | iOS 能力 scope、系统字号与应用倍率 |
| `lib/pages/video/introduction/ugc/view.dart` | 作者/操作区宽度与横屏间距 |
| `lib/pages/video/reply/widgets/reply_item_grpc.dart` | 评论业务更新与自定义操作菜单入口 |
| `lib/plugin/pl_player/utils/fullscreen.dart` | 全屏/播放页的系统栏可见性协调 |
| `pubspec.yaml` | 依赖、Flutter 基线与自有版本/构建号 |

上游 2.2.0.2 Release 提到投屏依赖、部分视频评论显示、课堂视频、弹幕跳转等修复；合并时还需检查跨越中间版本的完整 compare，而非仅依据最终版本的 Release 摘要。`pubspec.lock`、播放器控制器、选集与评论控制器也在上游变化范围。

最重要的回归场景：内外屏/旋转时页面与滚动状态保留；摄像头/折叠区的局部避让；底栏和侧栏滑动取消；推入页面后交互返回暂停/取消/完成时无玻璃穿透或发白；搜索中途反向与大字号不重叠；评论菜单居中；全屏退出与后台恢复后的状态栏；直播分类置顶。

## 10. 证据入口

- [项目 README](../README.md)
- [iOS 实现及历次迭代说明](ios-liquid-glass.md)
- [安装说明](ios-testing.md)
- [test18 动效验收](../design-qa.md)
- [test22 构建元数据](../dist/test22/build-info.json)
- [test22 本地发布说明](../dist/test22/release-notes.md)
- [本分支 GitHub](https://github.com/MichaelXiao-GIS/PiliPlus-LiquidGlass)
- [test22 Release](https://github.com/MichaelXiao-GIS/PiliPlus-LiquidGlass/releases/tag/v2.2.0-liquid-glass.test22)
- [test22 合并提交](https://github.com/MichaelXiao-GIS/PiliPlus-LiquidGlass/commit/cfacaed843457c95fb6238ed60487b4c9ab7d670)
- [当前定制与上游 2.2.0 比较](https://github.com/MichaelXiao-GIS/PiliPlus-LiquidGlass/compare/265f879fa85973b4bf885bde2562f1007f1013b8...cfacaed843457c95fb6238ed60487b4c9ab7d670)
- [上游 2.2.0.2 Release](https://github.com/bggRGjQaUbCoE/PiliPlus/releases/tag/2.2.0.2)
- [上游 2.2.0 至 2.2.0.2 比较](https://github.com/bggRGjQaUbCoE/PiliPlus/compare/2.2.0...2.2.0.2)

`dist/` 被 Git 忽略，本地的完整历史视觉材料不能由普通源码 clone 全部恢复；后续迁移应继续保留这些产物。
