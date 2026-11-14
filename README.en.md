<div align="center">
  <img src="assets/images/logo/logo.png" width="96" height="96" alt="PiliPlus logo" />
  <h1>PiliPlus Liquid Glass</h1>
  <p>An iOS interface fork of PiliPlus</p>
  <p>Native glass surfaces · Scroll-responsive navigation · iPhone and iPhone Duo layouts</p>

[中文](README.md) · English

[Download](https://github.com/MichaelXiao-GIS/PiliPlus-LiquidGlass/releases) · [Installation guide](docs/ios-testing.md) · [Upstream PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)

</div>

## About

**PiliPlus Liquid Glass** is a modified version of [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus), a third-party Bilibili client built with Flutter. It retains the upstream app's functionality while adapting navigation, search, settings and player controls for iOS.

This repository focuses on iPhone test builds, including window, safe-area and rotation handling for iOS 27.1 and iPhone Duo. Source code for other platforms is inherited from upstream; the Liquid Glass changes and releases presented here focus on iOS.

This fork is based on [PiliPlus 2.2.0.2](https://github.com/bggRGjQaUbCoE/PiliPlus/releases/tag/2.2.0.2). That release updated the episode picker and the download option for anime. It also fixed an issue that prevented some videos from showing all comments.

On iPhone Duo, the Profile tab shows your avatar when signed in. Messages and Search line up with the tab bar below. As you scroll through your inbox, messages blur behind the header.

## Changes in this fork

| Area | Experience |
| --- | --- |
| Home and search | A transparent header gains a soft blur while scrolling. The search field narrows and moves upward along a continuous arc, then expands at the top. Category tabs remain distinct. |
| Glass navigation | iOS 26 and later use the system glass tab bar. Home, Activity, and Profile keep their scroll positions when you switch tabs. |
| Landscape and Duo | Navigation adapts to the window, fold regions and camera position, reducing unused strips and content occlusion. |
| Video player | Separate title, shortcut and centered progress controls retain CC subtitles, speed and quality controls. The More menu groups secondary actions. |
| Settings and transitions | Grouped settings, light and dark themes, and iOS page transitions by default. Existing animation choices, text scaling and system accessibility preferences are retained. |

Video, anime, live streams, feeds, comments, favorites, history and offline caching come from PiliPlus. Availability depends on account permissions, the content and Bilibili's services.

## Current interface

Test build 31 on the Duo simulator, with a sample avatar and an offline inbox.

| Home sidebar | Scrolled inbox |
| --- | --- |
| [<img src="assets/screenshots/liquid_glass/duo-sidebar-test31.jpg" width="280" alt="The top actions align with the lower tab bar, which contains the profile avatar" />](assets/screenshots/liquid_glass/duo-sidebar-test31.jpg) | [<img src="assets/screenshots/liquid_glass/messages-test31.jpg" width="280" alt="Messages scroll behind the translucent header" />](assets/screenshots/liquid_glass/messages-test31.jpg) |

[View the system selection while dragging a Duo side tab](assets/screenshots/liquid_glass/duo-tab-drag-test31.jpg).

The Duo landscape screenshot below is from build 31. The iPad and standard iPhone screenshots are from build 30.

<table>
  <tr>
    <th>13-inch iPad Pro · Landscape</th>
    <th>iPhone Duo · Unfolded landscape</th>
  </tr>
  <tr>
    <td><a href="assets/screenshots/liquid_glass/ipad-landscape-test30.jpg"><img src="assets/screenshots/liquid_glass/ipad-landscape-test30.jpg" width="420" alt="Home recommendations with four videos per row" /></a></td>
    <td><a href="assets/screenshots/liquid_glass/duo-landscape-test31.jpg"><img src="assets/screenshots/liquid_glass/duo-landscape-test31.jpg" width="420" alt="Home recommendations with three videos per row" /></a></td>
  </tr>
</table>

<table>
  <tr>
    <th>iPhone · Home</th>
    <th>iPhone · After scrolling</th>
    <th>iPhone · Settings</th>
  </tr>
  <tr>
    <td><a href="assets/screenshots/liquid_glass/home-expanded-test30.jpg"><img src="assets/screenshots/liquid_glass/home-expanded-test30.jpg" width="280" alt="Expanded search field at the top of Home" /></a></td>
    <td><a href="assets/screenshots/liquid_glass/home-scrolled-test30.jpg"><img src="assets/screenshots/liquid_glass/home-scrolled-test30.jpg" width="280" alt="Compact search field and bottom bar after scrolling the feed" /></a></td>
    <td><a href="assets/screenshots/liquid_glass/settings-test30.jpg"><img src="assets/screenshots/liquid_glass/settings-test30.jpg" width="280" alt="Grouped settings with monochrome icons" /></a></td>
  </tr>
</table>

## Download and install

Download the IPA from [PiliPlus Liquid Glass test build 31](https://github.com/MichaelXiao-GIS/PiliPlus-LiquidGlass/releases/tag/v2.2.0-liquid-glass.test31), app version 2.2.0, build 31.

- **Package:** an arm64 Release build for iPhone, requiring iOS 15 or later.
- **Glass effects:** native Liquid Glass on iOS 26 and later, with a compatible material on older systems.
- **Signing:** re-sign the IPA with your own Apple ID using AltStore or Sideloadly before installing. Keep the same signing identity and app identifier when updating.
- **Assets:** IPA, `SHA256SUMS.txt` and `build-info.json`.

See the [installation guide](docs/ios-testing.md) for details (Chinese).

## Development and feedback

The [iOS adaptation and build guide](docs/ios-liquid-glass.md) covers the development environment, glass implementation and build process (Chinese). Release builds use `lib/main.dart`.

Report fork-specific problems in [this repository's Issues](https://github.com/MichaelXiao-GIS/PiliPlus-LiquidGlass/issues), including the build number, device, OS version, orientation, reproduction steps and screenshots. Redact personal information before attaching screenshots.

## Origin and disclaimer

This is an **independently maintained modification of PiliPlus**, focused on iOS Liquid Glass and adaptive layouts. It is not a client built from scratch or an official Bilibili app. Changes and test packages published here are maintained by this repository and do not represent upstream PiliPlus releases.

Thanks to these projects and all their contributors:

- [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus), the direct upstream of this fork.
- [orz12/PiliPalaX](https://github.com/orz12/PiliPalaX), the upstream of PiliPlus.
- [guozhigq/pilipala](https://github.com/guozhigq/pilipala), the original project.

This project is intended for open-source learning, interface research and personal testing. It does not provide cracked content or bypass paid access. Bilibili names, images and videos belong to their respective rights holders; screenshots illustrate the client interface.

This repository retains the upstream copyright notices and **GNU GPL v3** license. Use, modification and redistribution are governed by [LICENSE](LICENSE). The software is provided without warranty as described in that license.

## Other acknowledgements

- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
- [media-kit](https://github.com/media-kit/media-kit)
- [dio](https://pub.dev/packages/dio)
- The other open-source dependencies and contributors of PiliPlus.
