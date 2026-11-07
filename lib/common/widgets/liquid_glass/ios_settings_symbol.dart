import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Rasterize the installed system's SF Symbol once, then tint it with the theme.
/// No platform view per row and no icon background; the row supplies semantics.
class IosSettingsSymbol extends StatelessWidget {
  const IosSettingsSymbol({
    super.key,
    required this.name,
    required this.fallback,
  });
  final String name;
  final Widget fallback;
  static const _channel = MethodChannel('piliplus/liquid_glass');
  static final _cache = <(String, double, bool), Future<Uint8List?>>{};

  static Future<Uint8List?> _load(String name, double scale, bool bold) async {
    try {
      return await _channel.invokeMethod<Uint8List>('symbolImage', {
        'name': name,
        'scale': scale,
        'bold': bold,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final factor = (MediaQuery.textScalerOf(context).scale(22) / 22).clamp(
      1.0,
      2.0,
    );
    final scale = MediaQuery.devicePixelRatioOf(context) * factor;
    final bold = MediaQuery.boldTextOf(context);
    final color = ColorScheme.of(context).onSurfaceVariant;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 30 * factor,
        child: FutureBuilder<Uint8List?>(
          future: _cache.putIfAbsent((
            name,
            scale,
            bold,
          ), () => _load(name, scale, bold)),
          builder: (context, snapshot) {
            if (snapshot.data case final bytes?) {
              return Image.memory(bytes, color: color, gaplessPlayback: true);
            }
            return IconTheme(
              data: IconThemeData(size: 22 * factor, color: color),
              child: fallback,
            );
          },
        ),
      ),
    );
  }
}
