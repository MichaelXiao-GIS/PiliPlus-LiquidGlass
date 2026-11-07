import 'package:PiliPlus/pages/setting/view.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/ios/ios_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

class _EmptyAccounts extends Fake implements Box<LoginAccount> {
  @override
  bool get isEmpty => true;
}

void main() {
  setUpAll(() => Accounts.account = _EmptyAccounts());
  testWidgets('settings keeps its scroll state across Duo display changes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(466, 678);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: IosTheme.apply(ThemeData()),
        home: const SettingPage(),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(260);
    await tester.pumpAndSettle();
    for (final size in [
      const Size(669, 951),
      const Size(951, 669),
      const Size(466, 678),
      const Size(678, 466),
      const Size(466, 678),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(Scrollable).first), same(scroll));
      expect(scroll.position.pixels, 260);
      expect(tester.takeException(), isNull);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
