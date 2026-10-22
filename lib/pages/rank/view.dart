import 'package:PiliPlus/common/widgets/liquid_glass/glass_scroll_chrome.dart';
import 'package:PiliPlus/common/widgets/flutter/vertical_tabs.dart';
import 'package:PiliPlus/models/common/rank_type.dart';
import 'package:PiliPlus/pages/rank/controller.dart';
import 'package:PiliPlus/pages/rank/zone/view.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class RankPage extends StatefulWidget {
  const RankPage({super.key});

  @override
  State<RankPage> createState() => _RankPageState();
}

class _RankPageState extends State<RankPage>
    with AutomaticKeepAliveClientMixin {
  final RankController _rankController = Get.put(RankController());

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Padding(
          padding: EdgeInsets.only(top: GlassScrollInsets.topOf(context)),
          child: NotificationListener<Notification>(
            onNotification: (notification) =>
                GlassScrollInsets.topOf(context) > 0 &&
                (notification is ScrollNotification ||
                    notification is ScrollMetricsNotification),
            child: _buildTab(theme),
          ),
        ),
        Expanded(
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            controller: _rankController.tabController,
            children: RankType.values
                .map(
                  (item) => AnimatedBuilder(
                    animation: _rankController.tabController,
                    builder: (context, _) => GlassScrollBody(
                      active: _rankController.tabController.index == item.index,
                      child: ZonePage(
                        rid: item.rid,
                        seasonType: item.seasonType,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(ThemeData theme) {
    return VerticalTabBar(
      dividerWidth: 0,
      isScrollable: true,
      indicatorWeight: 3,
      indicatorSize: .tab,
      controller: _rankController.tabController,
      padding: .only(bottom: MediaQuery.paddingOf(context).bottom + 105),
      tabs: RankType.values.map((e) => VerticalTab(text: e.label)).toList(),
      onTap: (index) {
        if (!_rankController.tabController.indexIsChanging) {
          _rankController.animateToTop();
        } else {
          _rankController
            ..tabIndex.value = index
            ..tabController.animateTo(index);
        }
      },
    );
  }
}
