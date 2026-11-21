import 'dart:async';

import 'package:PiliPlus/pages/search/suggestion_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('clearing or replacing pending input avoids obsolete lookups', (
    tester,
  ) async {
    final calls = <String>[];
    final results = <String>[];
    final request = SuggestionRequest<String>((term) async {
      calls.add(term);
      return term;
    }, results.add);

    request.update('a');
    request.update('');
    await tester.pump(const Duration(milliseconds: 201));
    expect(calls, isEmpty);

    request.update('a');
    request.update('ab');
    await tester.pump(const Duration(milliseconds: 201));
    expect(calls, ['ab']);
    expect(results, ['ab']);
  });

  testWidgets('only the latest edit can publish, including repeated terms', (
    tester,
  ) async {
    final pending = <Completer<String>>[];
    final results = <String>[];
    final request = SuggestionRequest<String>((_) {
      final completer = Completer<String>();
      pending.add(completer);
      return completer.future;
    }, results.add);

    request.update('a', immediate: true);
    request.update('ab');
    request.update('a');
    await tester.pump(const Duration(milliseconds: 201));
    pending.last.complete('new');
    await tester.pump();
    pending.first.complete('stale');
    await tester.pump();
    expect(results, ['new']);

    request.update('b', immediate: true);
    request.cancel();
    pending.last.complete('after close');
    await tester.pump();
    expect(results, ['new']);
  });
}
