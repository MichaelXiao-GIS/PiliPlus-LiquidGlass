# iPhone 测试版安装

本测试版基于 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)，由 [PiliPlus Liquid Glass](https://github.com/MichaelXiao-GIS/PiliPlus-LiquidGlass) 分支维护，沿用上游许可证及版权声明。

## 获取安装包

从本仓库的 [Releases](https://github.com/MichaelXiao-GIS/PiliPlus-LiquidGlass/releases) 选择最新测试版，下载名称以 `.ipa` 结尾的附件。

当前版本为 [测试版 20](https://github.com/MichaelXiao-GIS/PiliPlus-LiquidGlass/releases/tag/v2.1.6-liquid-glass.test20)：

- 应用版本 2.1.6，构建号 20。
- 文件名：`PiliPlus-LiquidGlass-2.1.6-test20-ios-arm64.ipa`。
- 真机 arm64 Release 构建，使用 iOS 27.1 SDK，最低支持 iOS 15。
- 原生 Liquid Glass 在 iOS 26 及以上启用；旧系统使用兼容材质。
- 安装包只有打包用的 ad-hoc 签名，没有 Apple 开发者证书及设备描述文件，安装前需要重新签名。

## 签名与安装

可使用 [Sideloadly](https://sideloadly.io/) 或 [AltStore Classic](https://altstore.io/) 配合自己的 Apple ID 导入、签名和安装 IPA，具体操作以工具当前版本的提示为准。

使用 Sideloadly 时：

1. 在 macOS 或 Windows 上安装 Sideloadly，将 iPhone 连接到电脑并完成设备信任。
2. 选择设备，导入下载的 IPA，使用自己的 Apple ID 按提示签名安装。
3. 如果 iOS 要求开发者信任或开发者模式，按系统提示完成后打开应用。

已有 AltStore Classic 的用户可在其中导入 IPA。签名有效期及刷新由所用工具和账号管理。

## 更新已有安装

- 使用与此前一致的签名身份和应用标识覆盖安装，避免被识别为另一个应用。
- 建议先备份重要设置；应用内提供 WebDAV 设置备份与恢复。
- 每版功能变化见对应 Release 的说明，不需要按顺序安装旧测试版。

## 检查完整性

Release 同时提供 `SHA256SUMS.txt` 和 `build-info.json`。将它们与 IPA 放在同一目录，可在 macOS 的该目录中运行：

```sh
shasum -a 256 -c SHA256SUMS.txt
```

`build-info.json` 记录版本、构建号、源码提交与安装包校验值。

## 界面与使用

- 首页上滑时搜索框收拢、顶区渐变模糊，悬浮底栏缩小为图标；回到顶部恢复展开。
- 底栏和侧栏均支持水滴状滑动指示器，点击导航的原有行为保留。
- iPhone Duo 按窗口、折叠区域和旋转方向调整布局；如需自动旋转，请在外观设置中开启“横屏适配”。
- 全屏播放器保留 CC 字幕、倍速、画质和播放控制，其他操作集中在“更多”菜单。
- iOS 页面过渡默认启用，原有动画选项仍可在外观设置中选择。

问题反馈请提交到 [本仓库 Issues](https://github.com/MichaelXiao-GIS/PiliPlus-LiquidGlass/issues)，附上构建号、设备、系统版本与复现步骤。开发环境和源码构建见 [iOS 适配与构建说明](ios-liquid-glass.md)。
