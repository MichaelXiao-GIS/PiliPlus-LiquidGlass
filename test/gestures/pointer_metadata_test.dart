import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _MetadataProbe extends GestureRecognizer {
  _MetadataProbe()
    : super(allowedButtonsFilter: (buttons) => buttons == kPrimaryButton);

  final rejected = <int>[];

  (PointerDeviceKind, int) metadata(int pointer) =>
      (getKindForPointer(pointer), getButtonsForPointer(pointer));

  @override
  void handleNonAllowedPointer(PointerDownEvent event) =>
      rejected.add(event.pointer);

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {}

  @override
  String get debugDescription => 'pointer metadata probe';
}

void main() {
  test(
    'keeps metadata for each observed ID across interleaved input and reuse',
    () {
      final probe = _MetadataProbe();
      addTearDown(probe.dispose);
      probe.addPointer(const PointerDownEvent(pointer: 1));
      probe.addPointer(
        const PointerDownEvent(pointer: 2, kind: PointerDeviceKind.stylus),
      );
      probe.addPointer(const PointerDownEvent(pointer: 3));
      probe.addPointer(
        const PointerDownEvent(
          pointer: 4,
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryButton,
        ),
      );
      probe.addPointerPanZoom(const PointerPanZoomStartEvent(pointer: 5));

      const finger = (PointerDeviceKind.touch, kPrimaryButton);
      expect(probe.metadata(1), finger);
      expect(probe.metadata(3), finger);
      expect(probe.metadata(2), (PointerDeviceKind.stylus, kPrimaryButton));
      expect(probe.rejected, [4]);
      expect(probe.metadata(4), (PointerDeviceKind.mouse, kSecondaryButton));
      expect(probe.metadata(5), (PointerDeviceKind.trackpad, 0));

      // Reusing an exceptional ID for an ordinary touch must discard its old buttons.
      probe.addPointer(const PointerDownEvent(pointer: 4));
      expect(probe.metadata(4), finger);
      expect(probe.metadata(2), (PointerDeviceKind.stylus, kPrimaryButton));
    },
  );

  testWidgets(
    'a single tap retains its kind while double tap holds the arena',
    (tester) async {
      final kinds = <PointerDeviceKind?>[];
      var taps = 0;
      var doubleTaps = 0;
      await tester.pumpWidget(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => kinds.add(details.kind),
          onTap: () => taps++,
          onDoubleTap: () => doubleTaps++,
          child: const SizedBox.expand(),
        ),
      );
      const point = Offset(20, 20);
      final stylus = await tester.startGesture(
        point,
        kind: PointerDeviceKind.stylus,
      );
      await stylus.up();
      expect(taps, 0);
      expect(kinds, isEmpty);
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));
      expect(taps, 1);
      expect(kinds, [PointerDeviceKind.stylus]);

      await tester.tapAt(point);
      await tester.pump(kDoubleTapMinTime + const Duration(milliseconds: 1));
      await tester.tapAt(point);
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));
      expect(doubleTaps, 1);
      expect(taps, 1);
    },
  );
}
