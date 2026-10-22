import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Native capabilities are negotiated once, rather than assuming an OS version.
@immutable
class GlassCapabilities {
  const GlassCapabilities({
    this.nativeGlass = false,
    this.reduceTransparency = false,
    this.reduceMotion = false,
  });

  final bool nativeGlass;
  final bool reduceTransparency;
  final bool reduceMotion;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static GlassCapabilities of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassInherited>()?.value ??
      const GlassCapabilities();

  static Duration duration(BuildContext context, [int milliseconds = 250]) =>
      of(context).reduceMotion || MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);
}

class GlassPlatformScope extends StatefulWidget {
  const GlassPlatformScope({super.key, required this.child});

  final Widget child;

  @override
  State<GlassPlatformScope> createState() => _GlassPlatformScopeState();
}

class _GlassPlatformScopeState extends State<GlassPlatformScope>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('piliplus/liquid_glass');
  GlassCapabilities _value = const GlassCapabilities();

  @override
  void initState() {
    super.initState();
    if (GlassCapabilities.isIOS) {
      WidgetsBinding.instance.addObserver(this);
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'accessibilityChanged') await _refresh();
      });
      _refresh();
    }
  }

  Future<void> _refresh() async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'capabilities',
      );
      if (!mounted || data == null) return;
      setState(() {
        _value = GlassCapabilities(
          nativeGlass: data['nativeGlass'] == true,
          reduceTransparency: data['reduceTransparency'] == true,
          reduceMotion: data['reduceMotion'] == true,
        );
      });
    } on MissingPluginException {
      // Widget tests and older hosts use the Flutter material fallback.
    } on PlatformException {
      // Keep navigation usable if the native bridge is unavailable.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    if (GlassCapabilities.isIOS) {
      WidgetsBinding.instance.removeObserver(this);
      _channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _GlassInherited(
    value: _value,
    child: widget.child,
  );
}

class _GlassInherited extends InheritedWidget {
  const _GlassInherited({required this.value, required super.child});

  final GlassCapabilities value;

  @override
  bool updateShouldNotify(_GlassInherited oldWidget) =>
      oldWidget.value != value;
}
