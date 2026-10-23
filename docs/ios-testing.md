# iPhone 测试版安装

本测试版基于 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)，提供 iOS Liquid Glass 界面适配，保留原项目许可证及版权声明。

## 安装包

从本仓库的 [Releases](https://github.com/MichaelXiao-GIS/PiliPlus-LiquidGlass/releases) 下载 `PiliPlus-LiquidGlass-2.1.6-test6-ios-arm64.ipa`。

- 版本：2.1.6，Liquid Glass 测试版 6（构建号 6）。
- 架构：真机 arm64，Release 构建。
- 最低系统：iOS 15；原生 Liquid Glass 在 iOS 26 及以上启用。
- 签名：仅有打包用的 ad-hoc 代码签名，没有 Apple 开发者证书及设备描述文件。安装前需用自己的 Apple 身份重新签名。

## 使用 Sideloadly 安装

1. 从 [Sideloadly 官网](https://sideloadly.io/) 下载 macOS 或 Windows 版本。
2. 将 iPhone 连接到电脑，在手机上完成设备信任提示。
3. 在 Sideloadly 中选择自己的 iPhone，导入下载的 IPA，使用自己的 Apple ID 按界面提示签名安装。
4. 如果 iOS 提示开发者信任或开发者模式，按系统提示完成，再打开 PiliPlus。

已有 AltStore Classic 的用户也可通过它导入并重新签名 IPA；以当前版本的安装流程为准。签名及刷新由所用侧载工具管理。

## 检查完整性

Release 同时提供 `SHA256SUMS.txt` 和 `build-info.json`。macOS 可运行：

```sh
shasum -a 256 -c SHA256SUMS.txt
```

## 建议测试

- 首页分类、底栏导航、搜索、动态和资料库。
- 设置分组、主题切换、系统字号、VoiceOver。
- 减少透明度、增强对比度、减少动态效果。
- 视频开始播放、横屏全屏控制、退出全屏、后台音频和画中画。

测试版 5 修复分类选中胶囊边缘被裁切，并加入可收缩的首页搜索框：上滑时缩窄并上移到“浏览”和消息、头像之间，回到顶部时恢复整行。文字与放大镜在各状态下垂直居中。请同时检查展开、收起和回到顶部后的对齐、搜索点击、分类切换与下拉刷新。

竖屏保留此前的沉浸式顶区和居中悬浮底栏：顶部时透明并显示导航文字，滚动后顶区模糊、底栏缩小且仅显示图标。

此前的改进包括：横屏玻璃导航宽 72pt，内部图标居中；设置标题栏与搜索框净间距 28pt；原有完整动画列表和保存值保留，`native` 显示为“iOS 默认”。

测试版 6 适配 iOS 27.1 与 iPhone Duo：按当前窗口尺寸类别切换底栏和侧栏，处理活动折叠区域、摄像头和不对称安全区，保留内容与滚动状态；设置页按可用宽度切换单栏与双栏。请分别检查合上、展开、半展开、旋转和分屏后的布局。原来的“横屏适配”开关保留；如需自动旋转，请在外观设置中开启。

已通过 87 项自动测试，覆盖此前界面行为以及 Duo 的窗口信息、折叠区域和缩放。已在 iPhone Duo / iOS 27.1 模拟器检查内外屏、旋转和半展开布局。真实设备上的播放、画中画、登录及渲染性能仍以真机测试结果为准。

界面实现和构建环境说明见 [iOS Liquid Glass 适配](ios-liquid-glass.md)。
