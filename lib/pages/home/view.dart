import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/custom_height_widget.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_tab_bar.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/pages/home/widgets/collapsing_search_bar.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends CommonPageState<HomePage>
    with AutomaticKeepAliveClientMixin {
  late ColorScheme _colorScheme;
  final _homeController = Get.putOrFind(HomeController.new);
  final _mainController = Get.find<MainController>();

  @override
  bool get needsCorrection => _homeController.hideTopBar;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorScheme = ColorScheme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget tabBar;
    if (_homeController.tabs.length > 1) {
      tabBar = Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SizedBox(
          height: 42,
          width: double.infinity,
          child: TabBar(
            controller: _homeController.tabController,
            tabs: _homeController.tabs.map((e) => Tab(text: e.label)).toList(),
            isScrollable: true,
            dividerColor: Colors.transparent,
            dividerHeight: 0,
            splashBorderRadius: Style.mdRadius,
            tabAlignment: TabAlignment.center,
            onTap: (_) {
              feedBack();
              if (!_homeController.tabController.indexIsChanging) {
                _homeController.animateToTop();
              }
            },
          ),
        ),
      );
      if (GlassCapabilities.isIOS) {
        tabBar = GlassTabBar(
          controller: _homeController.tabController,
          labels: _homeController.tabs.map((e) => e.label).toList(),
          onTap: (_) {
            feedBack();
            if (!_homeController.tabController.indexIsChanging) {
              _homeController.animateToTop();
            }
          },
        );
      } else if (_homeController.hideTopBar &&
          _mainController.barHideType == .instant) {
        tabBar = Material(
          color: _colorScheme.surface,
          child: tabBar,
        );
      }
    } else {
      tabBar = const SizedBox(height: 6);
    }
    return Column(
      children: [
        if (GlassCapabilities.isIOS && _mainController.useBottomNav)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      '浏览',
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                        color: _colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                msgBadge(_mainController),
                const SizedBox(width: 6),
                userAvatar(
                  colorScheme: _colorScheme,
                  mainController: _mainController,
                ),
              ],
            ),
          ),
        if (!_mainController.useSideBar &&
            (GlassCapabilities.isIOS
                ? _mainController.useBottomNav
                : MediaQuery.sizeOf(context).isPortrait))
          customAppBar(),
        tabBar,
        Expanded(
          child: onBuild(
            tabBarView(
              controller: _homeController.tabController,
              children: _homeController.tabs.map((e) => e.page).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget customAppBar() {
    const padding = EdgeInsets.fromLTRB(14, 6, 14, 0);
    final child = Row(
      children: [
        searchBar(),
        if (!GlassCapabilities.isIOS) ...[
          const SizedBox(width: 4),
          msgBadge(_mainController),
          const SizedBox(width: 8),
          userAvatar(
            colorScheme: _colorScheme,
            mainController: _mainController,
          ),
        ],
      ],
    );
    if (GlassCapabilities.isIOS && _homeController.hideTopBar) {
      final search = Padding(padding: padding, child: child);
      if (_mainController.barOffset case final barOffset?) {
        return Obx(
          () => CollapsingSearchBar(
            fraction: 1 - barOffset.value / Style.topBarHeight,
            child: search,
          ),
        );
      }
      if (_homeController.showTopBar case final showTopBar?) {
        return Obx(
          () => TweenAnimationBuilder<double>(
            tween: Tween(end: showTopBar.value ? 1.0 : 0.0),
            curve: Curves.easeInOutCubicEmphasized,
            duration: GlassCapabilities.duration(context, 500),
            child: search,
            builder: (context, fraction, child) => CollapsingSearchBar(
              fraction: fraction,
              child: child!,
            ),
          ),
        );
      }
    }
    if (_homeController.hideTopBar) {
      if (_mainController.barOffset case final barOffset?) {
        return Obx(
          () {
            final offset = barOffset.value;
            return CustomHeightWidget(
              offset: Offset(0, -offset),
              height: Style.topBarHeight - offset,
              child: Padding(
                padding: padding,
                child: child,
              ),
            );
          },
        );
      }
      if (_homeController.showTopBar case final showTopBar?) {
        return Obx(() {
          final showSearchBar = showTopBar.value;
          return AnimatedOpacity(
            opacity: showSearchBar ? 1 : 0,
            duration: GlassCapabilities.duration(context, 300),
            child: AnimatedContainer(
              curve: Curves.easeInOutCubicEmphasized,
              duration: GlassCapabilities.duration(context, 500),
              height: showSearchBar ? Style.topBarHeight : 0,
              padding: padding,
              child: child,
            ),
          );
        });
      }
    }
    return Container(
      height: Style.topBarHeight,
      padding: padding,
      child: child,
    );
  }

  Widget searchBar() {
    if (GlassCapabilities.isIOS) {
      return Expanded(
        child: Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          label: '搜索视频、UP主和番剧',
          onTap: () => Get.toNamed(
            '/search',
            parameters: _homeController.enableSearchWord
                ? {'hintText': _homeController.defaultSearch.value}
                : null,
          ),
          child: GlassSurface(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                excludeFromSemantics: true,
                borderRadius: BorderRadius.circular(28),
                onTap: () => Get.toNamed(
                  '/search',
                  parameters: _homeController.enableSearchWord
                      ? {'hintText': _homeController.defaultSearch.value}
                      : null,
                ),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: _colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Obx(
                          () => Text(
                            _homeController.defaultSearch.value.isEmpty
                                ? '搜索视频、UP主和番剧'
                                : _homeController.defaultSearch.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              color: _colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    const borderRadius = BorderRadius.all(Radius.circular(25));
    return Expanded(
      child: SizedBox(
        height: 44,
        child: Material(
          borderRadius: borderRadius,
          color: _colorScheme.onSecondaryContainer.withValues(alpha: 0.05),
          child: InkWell(
            borderRadius: borderRadius,
            splashColor: _colorScheme.primaryContainer.withValues(
              alpha: 0.3,
            ),
            onTap: () => Get.toNamed(
              '/search',
              parameters: _homeController.enableSearchWord
                  ? {'hintText': _homeController.defaultSearch.value}
                  : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.search_outlined,
                  color: _colorScheme.onSecondaryContainer,
                  semanticLabel: '搜索',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Obx(
                    () => Text(
                      _homeController.defaultSearch.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _colorScheme.outline),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget userAvatar({
  required ColorScheme colorScheme,
  required MainController mainController,
}) {
  return Semantics(
    container: true,
    label: "我的",
    child: Obx(
      () {
        if (mainController.accountService.isLogin.value) {
          return Stack(
            clipBehavior: .none,
            children: [
              NetworkImgLayer(
                type: .avatar,
                width: GlassCapabilities.isIOS ? 44 : 34,
                height: GlassCapabilities.isIOS ? 44 : 34,
                src: mainController.accountService.face.value,
              ),
              Positioned.fill(
                child: Material(
                  type: .transparency,
                  child: InkWell(
                    onTap: mainController.toMinePage,
                    splashColor: colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    customBorder: const CircleBorder(),
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Obx(
                  () => MineController.anonymity.value
                      ? IgnorePointer(
                          child: Container(
                            padding: const .all(2),
                            decoration: BoxDecoration(
                              shape: .circle,
                              color: colorScheme.secondaryContainer,
                            ),
                            child: Icon(
                              size: 14,
                              MdiIcons.incognito,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          );
        }
        return SizedBox(
          width: GlassCapabilities.isIOS ? 44 : 38,
          height: GlassCapabilities.isIOS ? 44 : 38,
          child: IconButton(
            tooltip: '点击登录',
            style: IconButton.styleFrom(
              padding: .zero,
              backgroundColor: colorScheme.onInverseSurface,
            ),
            onPressed: mainController.toMinePage,
            icon: Icon(
              Icons.person_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
          ),
        );
      },
    ),
  );
}

Widget msgBadge(MainController mainController) {
  return Obx(
    () {
      if (mainController.accountService.isLogin.value) {
        final count = mainController.msgUnReadCount.value;
        final isNumBadge = mainController.msgBadgeMode == .number;
        return IconButton(
          tooltip: '消息',
          onPressed: () {
            mainController
              ..clearUnreadMsg()
              ..lastCheckUnreadAt = DateTime.now().millisecondsSinceEpoch;
            Get.toNamed('/whisper');
          },
          icon: Badge(
            isLabelVisible:
                mainController.msgBadgeMode != .hidden && count != null,
            alignment: isNumBadge
                ? const Alignment(0.0, -0.85)
                : const Alignment(1.0, -0.85),
            label: isNumBadge && count != null ? Text(count) : null,
            child: const Icon(Icons.notifications_none),
          ),
        );
      }
      return const SizedBox.shrink();
    },
  );
}
