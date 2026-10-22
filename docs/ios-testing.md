# iPhone 测试版安装

本测试版基于 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)，提供 iOS Liquid Glass 界面适配，保留原项目许可证及版权声明。

## 安装包

从本仓库的 [Releases](https://github.com/MichaelXiao-GIS/PiliPlus-LiquidGlass/releases) 下载 `PiliPlus-LiquidGlass-2.1.6-test4-ios-arm64.ipa`。

- 版本：2.1.6，Liquid Glass 测试版 4（构建号 4）。
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

测试版 4 将竖屏底栏收拢为居中悬浮胶囊：三个入口、标准字号时宽 262pt，放大字号后适当加宽，窄屏时按可用空间收缩。原有文字、未读提示、导航和重复点击行为继续保留。

此前的改进包括：横屏玻璃导航宽 72pt，内部图标居中；设置标题栏与搜索框净间距 28pt；原有完整动画列表和保存值保留，`native` 显示为“iOS 默认”。

已通过 45 项自动测试，覆盖横屏两种方向的安全区与居中、设置间距、动画选择保存、原有动画、iOS 推入返回和侧滑取消。iOS 27.0 模拟器已检查页面布局。真实设备上的播放、画中画、登录及渲染性能仍以真机测试结果为准。

界面实现和构建环境说明见 [iOS Liquid Glass 适配](ios-liquid-glass.md)。
