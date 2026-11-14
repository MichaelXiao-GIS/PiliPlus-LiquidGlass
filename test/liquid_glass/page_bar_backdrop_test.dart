import 'dart:ui' as ui;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_page_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/ios_settings_symbol.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/utils/ios/ios_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart'
    show RenderObject, RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('overlapping scaffold slots expose semantics in paint order', (
    tester,
  ) async {
    const body = ValueKey('body');
    const bar = ValueKey('toolbar');
    const fab = ValueKey('fab');
    Widget button(Key key) => Semantics(
      key: key,
      container: true,
      button: true,
      label: key.toString(),
      child: const SizedBox(width: 48, height: 48),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ScaffoldLayout(
          overlayAppBar: true,
          body: button(body),
          appBar: button(bar),
          fab: button(fab),
        ),
      ),
    );
    final scaffold = tester.renderObject(find.byType(ScaffoldLayout));
    final children = <RenderObject>[];
    scaffold.visitChildrenForSemantics(children.add);
    final widgets = [body, bar, fab].map((key) => find.byKey(key));
    expect(children, orderedEquals(widgets.map(tester.renderObject)));
    expect(
      tester
          .getRect(find.byKey(body))
          .contains(tester.getCenter(find.byKey(bar))),
      isTrue,
    );
    expect(
      tester
          .getRect(find.byKey(body))
          .contains(tester.getCenter(find.byKey(fab))),
      isTrue,
    );
  });

  testWidgets('nested comment controls stop below the translucent toolbar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final nested = GlobalKey<NestedScrollViewState>();
    const tabsKey = ValueKey('comment tabs');
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 60)),
          child: SimpleScaffold(
            overlayAppBar: true,
            appBar: AppBar(title: const Text('动态详情')),
            body: NestedScrollView(
              key: nested,
              headerSliverBuilder: (_, _) => const [
                SliverToBoxAdapter(child: SizedBox(height: 600)),
              ],
              body: GlassNestedScrollBody(
                child: Column(
                  children: [
                    const SizedBox(key: tabsKey, height: 40),
                    Expanded(
                      child: ListView.builder(
                        itemExtent: 70,
                        itemCount: 50,
                        itemBuilder: (_, index) => Text('comment $index'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(tabsKey)).dy, 600);
    final outer = nested.currentState!.outerController;
    outer.jumpTo(outer.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(tabsKey)).dy, 130);
    outer.jumpTo(outer.position.maxScrollExtent - 50);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(tabsKey)).dy, 130);
    outer.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(tabsKey)).dy, 600);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'overlay keeps the viewport behind the bar and toolbar hit testing above it',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var toolbarTaps = 0;
      var bodyTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: IosTheme.apply(ThemeData()),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              padding: EdgeInsets.only(top: 60),
            ),
            child: Builder(
              builder: (context) => SimpleScaffold(
                overlayAppBar: true,
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => toolbarTaps++,
                  ),
                ),
                body: ListView.builder(
                  key: const ValueKey('feed'),
                  controller: scroll,
                  padding: EdgeInsets.only(top: GlassPageBar.topInset(context)),
                  itemExtent: 70,
                  itemCount: 40,
                  itemBuilder: (_, index) => TextButton(
                    onPressed: () => bodyTaps++,
                    child: Text('row $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const ValueKey('feed'))).dy, 0);
      expect(tester.getTopLeft(find.text('row 0')).dy, greaterThan(130));
      scroll.jumpTo(300);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(toolbarTaps, 1);
      expect(bodyTaps, 0);
      expect(scroll.offset, 300);
      // The feather extends below the toolbar without intercepting the list.
      await tester.tapAt(const Offset(200, 145));
      expect(bodyTaps, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'page header blurs the backdrop and fades into readable content',
    (
      tester,
    ) async {
      const pixelsKey = ValueKey('page-header-pixels');
      await tester.pumpWidget(
        MaterialApp(
          theme: IosTheme.apply(ThemeData()),
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 300,
              child: RepaintBoundary(
                key: pixelsKey,
                child: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(300, 300),
                    padding: EdgeInsets.only(top: 60),
                  ),
                  child: SimpleScaffold(
                    overlayAppBar: true,
                    appBar: AppBar(title: const Text('设置')),
                    body: Row(
                      children: [
                        for (var i = 0; i < 75; i++)
                          Expanded(
                            child: ColoredBox(
                              color: i.isEven ? Colors.black : Colors.white,
                              child: const SizedBox.expand(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pixels = await tester.runAsync(() async {
        final image = await tester
            .renderObject<RenderRepaintBoundary>(find.byKey(pixelsKey))
            .toImage(pixelRatio: 1);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return bytes!;
      });
      int red(int x, int y) => pixels!.getUint8((y * 300 + x) * 4);
      int contrast(int y) => (red(121, y) - red(125, y)).abs();
      expect(contrast(30), lessThan(15));
      // The surface remains translucent, rather than painting a white panel.
      expect(red(121, 30), inInclusiveRange(130, 170));
      expect(contrast(135), lessThan(contrast(150)));
      expect(contrast(150), lessThan(contrast(180)));
      // Crossing the old toolbar edge must not suddenly reveal sharp content.
      expect((red(121, 129) - red(121, 130)).abs(), lessThan(15));
      expect(contrast(160), greaterThan(230));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('opaque accessibility mode disables header backdrop filtering', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: IosTheme.apply(ThemeData()),
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: SimpleScaffold(
            overlayAppBar: true,
            appBar: AppBar(title: const Text('设置')),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final filters = tester.widgetList<BackdropFilter>(
      find.byType(BackdropFilter),
    );
    expect(filters, isNotEmpty);
    expect(filters.every((f) => !f.enabled), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'system symbols use a single native request across theme changes and have a fallback',
    (tester) async {
      const channel = MethodChannel('piliplus/liquid_glass');
      var calls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'symbolImage');
        expect(call.arguments['name'], 'lock.shield');
        calls++;
        return null; // A missing symbol on an older OS still has a visible icon.
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      Widget app(Brightness brightness) => MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const IosSettingsSymbol(
          name: 'lock.shield',
          fallback: Icon(Icons.shield),
        ),
      );
      await tester.pumpWidget(app(Brightness.light));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.shield), findsOneWidget);
      await tester.pumpWidget(app(Brightness.dark));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
