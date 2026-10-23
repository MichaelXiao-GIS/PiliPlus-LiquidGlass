import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_scroll_chrome.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_tab_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_window_geometry.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/common/dynamic/up_panel_position.dart';
import 'package:PiliPlus/models/dynamics/up.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/dynamics/widgets/up_panel.dart';
import 'package:PiliPlus/pages/dynamics_create/view.dart';
import 'package:PiliPlus/pages/dynamics_tab/view.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide DraggableScrollableSheet;

class DynamicsPage extends StatefulWidget {
  const DynamicsPage({super.key});

  @override
  State<DynamicsPage> createState() => _DynamicsPageState();
}

class _DynamicsPageState extends CommonPageState<DynamicsPage>
    with AutomaticKeepAliveClientMixin {
  final _dynamicsController = Get.putOrFind(DynamicsController.new);
  UpPanelPosition get upPanelPosition => _dynamicsController.upPanelPosition;
  late final MainController _mainController = Get.find<MainController>();
  final _bodyKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  Widget _createDynamicBtn(ColorScheme colorScheme, {bool isRight = true}) =>
      Container(
        width: GlassCapabilities.isIOS ? 44 : 34,
        height: GlassCapabilities.isIOS ? 44 : 34,
        margin: GlassCapabilities.isIOS
            ? EdgeInsets.zero
            : isRight
            ? const .only(right: 16)
            : const .only(left: 16),
        child: IconButton(
          tooltip: '发布动态',
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            backgroundColor: WidgetStatePropertyAll(
              GlassCapabilities.isIOS
                  ? Colors.transparent
                  : colorScheme.secondaryContainer,
            ),
          ),
          onPressed: () => CreateDynPanel.onCreateDyn(context),
          icon: Icon(
            Icons.add,
            size: GlassCapabilities.isIOS ? 22 : 18,
            color: GlassCapabilities.isIOS
                ? colorScheme.onSurface
                : colorScheme.onSecondaryContainer,
          ),
        ),
      );

  Widget upPanelPart(ColorScheme colorScheme) {
    final isTop = upPanelPosition == .top;
    final needBg = upPanelPosition.index > 2;
    final top =
        GlassScrollPage.enabled(context) &&
            (upPanelPosition == .leftFixed || upPanelPosition == .rightFixed)
        ? MediaQuery.viewPaddingOf(context).top +
              GlassTabBar.heightOf(context) +
              14
        : 0.0;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Material(
        type: needBg ? .canvas : .transparency,
        color: needBg ? colorScheme.surface : null,
        child: SizedBox(
          width: isTop ? null : 64,
          height: isTop ? 76 : null,
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (notification) {
              final metrics = notification.metrics;
              if (metrics.pixels >= metrics.maxScrollExtent - 300) {
                _dynamicsController.onLoadMore();
              }
              return false;
            },
            child: Obx(
              () => _buildUpPanel(_dynamicsController.loadingState.value),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpPanel(LoadingState<FollowUpModel> upState) {
    return switch (upState) {
      Loading() => const SizedBox.shrink(),
      Success(:final response) => UpPanel(
        upData: response,
        dynamicsController: _dynamicsController,
      ),
      Error() => Center(
        child: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _dynamicsController.onReload,
        ),
      ),
    };
  }

  bool get checkPage =>
      _mainController.navigationBars[0] != .dynamics &&
      _mainController.selectedIndex.value == 0;

  @override
  bool onNotificationType1(UserScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType1(notification);
  }

  @override
  bool onNotificationType2(ScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType2(notification);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);

    Widget? drawer;
    Widget? endDrawer;

    Widget? leading;
    Widget actions;

    final immersive = GlassScrollPage.enabled(context);
    Widget child = AnimatedBuilder(
      key: _bodyKey,
      animation: _dynamicsController.tabController,
      builder: (context, _) => tabBarView(
        controller: _dynamicsController.tabController,
        children: [
          for (final type in DynamicsTabType.values)
            GlassScrollBody(
              active: _dynamicsController.tabController.index == type.index,
              child: DynamicsTabPage(dynamicsType: type),
            ),
        ],
      ),
    );

    switch (upPanelPosition) {
      case .top:
        if (!immersive) {
          child = Column(
            children: [
              upPanelPart(colorScheme),
              Expanded(child: child),
            ],
          );
        }
        actions = _createDynamicBtn(colorScheme);
      case .leftFixed:
        child = Row(
          children: [
            upPanelPart(colorScheme),
            Expanded(child: child),
          ],
        );
        actions = _createDynamicBtn(colorScheme);
      case .rightFixed:
        child = Row(
          children: [
            Expanded(child: child),
            upPanelPart(colorScheme),
          ],
        );
        actions = _createDynamicBtn(colorScheme);
      case .leftDrawer:
        drawer = upPanelPart(colorScheme);
        actions = _createDynamicBtn(colorScheme);
        leading = const DrawerButton();
      case .rightDrawer:
        endDrawer = upPanelPart(colorScheme);
        leading = _createDynamicBtn(colorScheme, isRight: false);
        actions = const EndDrawerButton();
    }

    if (immersive) {
      return Scaffold(
        primary: false,
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        drawer: drawer,
        endDrawer: endDrawer,
        body: GlassScrollPage(
          headerExtent:
              GlassTabBar.heightOf(context) +
              14 +
              (upPanelPosition == .top ? 76 : 0),
          header: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Row(
                  children: [
                    ?leading,
                    Expanded(
                      child: GlassTabBar(
                        controller: _dynamicsController.tabController,
                        labels: DynamicsTabType.values
                            .map((e) => e.label)
                            .toList(),
                        onTap: (_) {
                          if (!_dynamicsController
                              .tabController
                              .indexIsChanging) {
                            _dynamicsController.animateToTop();
                          }
                        },
                      ),
                    ),
                    GlassSurface(child: actions),
                  ],
                ),
              ),
              if (upPanelPosition == .top) upPanelPart(colorScheme),
            ],
          ),
          body: child,
        ),
      );
    }

    return Scaffold(
      primary: false,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: GlassCapabilities.isIOS
          ? PreferredSize(
              preferredSize: Size.fromHeight(
                GlassTabBar.heightOf(context) + 14,
              ),
              child: GlassControlBand(
                height: GlassTabBar.heightOf(context) + 14,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Row(
                    children: [
                      ?leading,
                      Expanded(
                        child: GlassTabBar(
                          controller: _dynamicsController.tabController,
                          labels: DynamicsTabType.values
                              .map((e) => e.label)
                              .toList(),
                          onTap: (_) {
                            if (!_dynamicsController
                                .tabController
                                .indexIsChanging) {
                              _dynamicsController.animateToTop();
                            }
                          },
                        ),
                      ),
                      GlassSurface(child: actions),
                    ],
                  ),
                ),
              ),
            )
          : PreferredSize(
              preferredSize: const .fromHeight(50),
              child: Row(
                children: [
                  ?leading,
                  Expanded(
                    child: TabBar(
                      dividerHeight: 0,
                      isScrollable: true,
                      tabAlignment: .start,
                      dividerColor: Colors.transparent,
                      labelColor: colorScheme.primary,
                      indicatorColor: colorScheme.primary,
                      controller: _dynamicsController.tabController,
                      unselectedLabelColor: colorScheme.onSurface,
                      labelStyle:
                          TabBarTheme.of(context).labelStyle
                              ?.copyWith(fontSize: 13) ??
                          const TextStyle(fontSize: 13),
                      tabs: DynamicsTabType.values
                          .map((e) => Tab(text: e.label))
                          .toList(),
                      onTap: (index) {
                        if (!_dynamicsController
                            .tabController
                            .indexIsChanging) {
                          _dynamicsController.animateToTop();
                        }
                      },
                    ),
                  ),
                  actions,
                ],
              ),
            ),
      drawer: drawer,
      endDrawer: endDrawer,
      body: onBuild(child),
    );
  }
}
