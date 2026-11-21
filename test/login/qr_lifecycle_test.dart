import 'dart:async';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Code = ({String authCode, String url});

class _Controller extends LoginPageController {
  final codes = <Completer<LoadingState<_Code>>>[];
  final polls = <Completer<Map>>[];

  @override
  Future<LoadingState<_Code>> fetchQrCode() {
    final request = Completer<LoadingState<_Code>>();
    codes.add(request);
    return request.future;
  }

  @override
  Future<Map> pollQrCode(String authCode) {
    final request = Completer<Map>();
    polls.add(request);
    return request.future;
  }
}

void main() {
  const code = Success((authCode: 'test', url: 'test'));
  testWidgets('pending QR generation is shared and cannot outlive the page', (
    tester,
  ) async {
    final controller = _Controller()..onInit();
    controller.tabController.index = 2;
    controller.refreshQRCode();
    controller.tabController.index = 0;
    controller.tabController.index = 2;
    expect(controller.codes, hasLength(1));

    controller.onClose();
    controller.codes.single.complete(code);
    await tester.pump();
    expect(controller.qrCodeTimer, isNull);
    expect(controller.codeInfo.value, isA<Loading>());
  });

  testWidgets('refresh and tab changes discard obsolete poll responses', (
    tester,
  ) async {
    final controller = _Controller()..onInit();
    addTearDown(controller.onClose);
    controller.tabController.index = 2;
    controller.codes.single.complete(code);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.polls, hasLength(1));

    controller.refreshQRCode();
    controller.codes.last.complete(code);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.polls, hasLength(2));
    controller.polls.first.complete({'status': false, 'msg': 'old'});
    controller.tabController.index = 0;
    controller.tabController.index = 2;
    controller.polls.last.complete({'status': false, 'msg': 'hidden'});
    await tester.pump();
    expect(controller.statusQRCode.value, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    controller.polls.last.complete({'status': false, 'msg': 'current'});
    await tester.pump();
    expect(controller.statusQRCode.value, 'current');
    controller.qrCodeTimer?.cancel();
  });
}
