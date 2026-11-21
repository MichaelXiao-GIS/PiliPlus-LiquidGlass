import 'package:PiliPlus/pages/history/controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _HistoryRequests extends HistoryController {
  _HistoryRequests(super.type);

  int statusRequests = 0;
  int listRequests = 0;

  @override
  Future<void> historyStatus() async {
    statusRequests++;
  }

  @override
  Future<void> queryData([bool isRefresh = true]) async {
    listRequests++;
  }
}

void main() {
  testWidgets('only the main history page loads the shared pause status', (
    tester,
  ) async {
    for (final type in [null, 'archive', 'live']) {
      final controller = _HistoryRequests(type);
      controller.onInit();
      expect(controller.statusRequests, type == null ? 1 : 0);
      expect(controller.listRequests, 1);
      controller.onClose();
    }
    await tester.pump();
  });
}
