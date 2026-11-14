import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_page_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_scroll_chrome.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:material_ui/material_ui.dart';

class MessageFeedScaffold extends StatelessWidget {
  const MessageFeedScaffold({
    super.key,
    required this.appBar,
    required this.onRefresh,
    required this.sliver,
  });

  final AppBar appBar;
  final Future<void> Function() onRefresh;
  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      overlayAppBar: true,
      appBar: appBar,
      body: GlassScrollInsets(
        top: GlassPageBar.topInset(context),
        child: refreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const GlassScrollSpacer(),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
                ),
                sliver: sliver,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
