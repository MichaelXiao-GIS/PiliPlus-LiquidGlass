import 'dart:async';

import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final nativeTabRoutes = NativeTabRouteObserver();

/// A popped popup can keep painting its barrier after the main route is current.
class NativeTabRouteObserver extends NavigatorObserver {
  final _exiting = <TransitionRoute<dynamic>>{};

  bool get isExiting => _exiting.isNotEmpty;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is TransitionRoute<dynamic>) {
      _exiting.add(route);
      route.completed.then((_) {
        _exiting.remove(route);
        WidgetsBinding.instance.ensureVisualUpdate();
      });
    }
  }
}

/// Synchronizes UIKit after layout, when the active retained feed, window size
/// and popup state all describe the frame actually being displayed.
class NativeMainTabs extends StatefulWidget {
  const NativeMainTabs({
    super.key,
    required this.enabled,
    required this.destinations,
    required this.selectedIndex,
    required this.axis,
    required this.tint,
    required this.dark,
    required this.onSelected,
    required this.position,
    required this.modalOverlayVisible,
    required this.onInstalled,
  });

  final bool enabled;
  final List<Map<String, Object?>> destinations;
  final int selectedIndex;
  final Axis axis;
  final int tint;
  final bool dark;
  final ValueChanged<int> onSelected;
  final ScrollPosition? Function() position;
  final bool Function() modalOverlayVisible;
  final ValueChanged<bool> onInstalled;

  @override
  State<NativeMainTabs> createState() => _NativeMainTabsState();
}

class _NativeMainTabsState extends State<NativeMainTabs>
    with WidgetsBindingObserver {
  ModalRoute<dynamic>? _route;
  double _scale = 1;
  bool _configured = false;
  Timer? _retry;
  int _attempt = 0;
  bool _visible = false;
  bool _dirty = true;
  int _revision = 0;
  (double, double, double)? _lastScroll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GlassCapabilities.onNativeTabSelected = _select;
    WidgetsBinding.instance.addPostFrameCallback(_afterFrame);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _scale =
        MediaQuery.devicePixelRatioOf(context) /
        View.of(context).devicePixelRatio;
  }

  @override
  void didUpdateWidget(NativeMainTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) _resetRetries();
    if (widget.enabled != oldWidget.enabled ||
        widget.selectedIndex != oldWidget.selectedIndex ||
        widget.axis != oldWidget.axis ||
        widget.tint != oldWidget.tint ||
        widget.dark != oldWidget.dark ||
        !const DeepCollectionEquality().equals(
          widget.destinations,
          oldWidget.destinations,
        )) {
      _dirty = true;
      _lastScroll = null;
    }
  }

  bool get _canShow {
    final route = _route;
    return widget.enabled &&
        route != null &&
        route.isCurrent &&
        !route.willHandlePopInternally &&
        !nativeTabRoutes.isExiting &&
        route.navigator?.userGestureInProgress != true &&
        (route.animation?.isCompleted ?? true) &&
        (route.secondaryAnimation?.isDismissed ?? true) &&
        !widget.modalOverlayVisible();
  }

  void _select(int index) {
    if (mounted &&
        _canShow &&
        index >= 0 &&
        index < widget.destinations.length) {
      widget.onSelected(index);
    }
  }

  void _afterFrame(Duration _) {
    if (!mounted) return;
    // Register for the next existing frame. In particular SmartDialog overlays
    // and local-history drawers can change without a new Navigator route.
    WidgetsBinding.instance.addPostFrameCallback(_afterFrame);
    final visible = _canShow;
    if (visible != _visible) _resetRetries();
    if (!visible && !_configured && !_visible) return;
    if (_visible != visible || _dirty) {
      _visible = visible;
      _dirty = false;
      _lastScroll = null;
      unawaited(_configure(++_revision, visible));
    }
    if (!visible || !_configured) return;
    final position = widget.position();
    final (double, double, double) metrics;
    if (position != null &&
        position.hasContentDimensions &&
        position.hasPixels &&
        position.maxScrollExtent.isFinite &&
        position.viewportDimension.isFinite) {
      final max = (position.maxScrollExtent - position.minScrollExtent).clamp(
        0.0,
        double.infinity,
      );
      metrics = (
        (position.pixels - position.minScrollExtent).clamp(0.0, max) * _scale,
        max * _scale,
        position.viewportDimension * _scale,
      );
    } else {
      metrics = (0.0, 0.0, 0.0);
    }
    if (_lastScroll == metrics) return;
    _lastScroll = metrics;
    final destinationId =
        widget.destinations[widget.selectedIndex]['id'] as String;
    unawaited(_scroll(destinationId, metrics));
  }

  Future<void> _scroll(
    String destinationId,
    (double, double, double) metrics,
  ) async {
    try {
      await GlassCapabilities.channel.invokeMethod<void>('nativeTabScroll', {
        'destinationId': destinationId,
        'offset': metrics.$1,
        'max': metrics.$2,
        'viewport': metrics.$3,
      });
    } on PlatformException {
      // Scrolling in Flutter continues if the native controller was dismissed.
    } on MissingPluginException {
      // The host may already have been torn down.
    }
  }

  void _resetRetries() {
    _retry?.cancel();
    _retry = null;
    _attempt = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resetRetries();
      _dirty = true;
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  Future<void> _configure(int revision, bool visible) async {
    bool installed = false;
    try {
      installed =
          await GlassCapabilities.channel.invokeMethod<bool>('setNativeTabs', {
            'destinations': widget.destinations,
            'selectedIndex': widget.selectedIndex,
            'visible': visible,
            'axis': widget.axis.name,
            'tint': widget.tint,
            'dark': widget.dark,
          }) ==
          true;
    } on PlatformException {
      // Keep the Flutter controls available if installation fails.
    } on MissingPluginException {
      // A host can lack this method even if it provides the glass material.
    }
    if (!mounted || revision != _revision) return;
    if (installed) {
      _resetRetries();
    } else if (visible && _attempt < 4 && _retry == null) {
      // Cold start or a native presentation can temporarily prevent embedding.
      _retry = Timer(Duration(milliseconds: 250 << _attempt++), () {
        _retry = null;
        _dirty = true;
        WidgetsBinding.instance.ensureVisualUpdate();
      });
    }
    final active = widget.enabled && installed && (visible || _configured);
    if (_configured != active) {
      _configured = active;
      widget.onInstalled(active);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resetRetries();
    if (GlassCapabilities.onNativeTabSelected == _select) {
      GlassCapabilities.onNativeTabSelected = null;
      if (widget.enabled || _configured) {
        unawaited(_hide());
      }
    }
    super.dispose();
  }

  Future<void> _hide() async {
    try {
      await GlassCapabilities.channel.invokeMethod<bool>('setNativeTabs', {
        'visible': false,
      });
    } on PlatformException {
      // The native scene may already be disconnected.
    } on MissingPluginException {
      // The host may already have been torn down.
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
