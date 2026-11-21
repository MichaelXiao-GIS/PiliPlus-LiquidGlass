import 'dart:async';

/// Keeps pending suggestions tied to the edit that requested them.
class SuggestionRequest<T> {
  SuggestionRequest(this.fetch, this.publish);

  final Future<T> Function(String) fetch;
  final void Function(T) publish;
  Timer? _timer;
  int _revision = 0;

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _revision++;
  }

  void update(String term, {bool immediate = false}) {
    cancel();
    if (term.isEmpty) return;
    final revision = _revision;

    Future<void> run() async {
      _timer = null;
      final result = await fetch(term);
      if (_revision == revision) publish(result);
    }

    if (immediate) {
      unawaited(run());
    } else {
      _timer = Timer(const Duration(milliseconds: 200), run);
    }
  }
}
