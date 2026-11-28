import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/models_new/video/video_play_info/subtitle.dart';
import 'package:PiliPlus/services/download/offline_subtitles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory entry;
  final english = Subtitle(id: 1, lan: 'en', subtitleUrl: 'en');
  final french = Subtitle(id: 2, lan: 'fr', subtitleUrl: 'fr');
  const old = '{"body":[{"from":0,"to":1,"content":"old"}]}';
  const fresh = '{"body":[{"from":0,"to":1,"content":"new"}]}';

  setUp(() async {
    entry = await Directory.systemTemp.createTemp('offline-subtitles-');
    final existing = File(english.toPath(entry.path));
    await existing.create(recursive: true);
    await existing.writeAsString(old);
  });
  tearDown(() => entry.delete(recursive: true));

  test(
    'publishes only after the whole set is downloaded and written',
    () async {
      final requested = Completer<void>();
      final response = Completer<List<int>>();
      final pending = saveOfflineSubtitles(
        entry.path,
        [english, french],
        fetch: (url) async {
          if (url == 'en') return utf8.encode(fresh);
          requested.complete();
          return response.future;
        },
      );
      await requested.future;
      expect(await File(english.toPath(entry.path)).readAsString(), old);
      expect(await File(french.toPath(entry.path)).exists(), isFalse);
      response.complete(utf8.encode(fresh));
      final saved = await pending;
      expect(saved.map((s) => s.lan), ['en', 'fr']);
      for (final subtitle in saved) {
        expect(await File(subtitle.path).readAsString(), fresh);
      }
    },
  );

  for (final failure in ['fetch', 'empty', 'invalid cue']) {
    test('retains cached tracks on $failure failure', () async {
      final pending = saveOfflineSubtitles(
        entry.path,
        [english, french],
        fetch: (url) async {
          if (url == 'en') return utf8.encode(fresh);
          if (failure == 'fetch') throw const SocketException('offline');
          if (failure == 'empty') return null;
          return utf8.encode('{"body":[{}]}');
        },
      );
      await expectLater(pending, throwsA(isA<Exception>()));
      final existing = File(english.toPath(entry.path));
      expect(await existing.readAsString(), old);
      expect(await existing.parent.list().map((f) => f.path).toList(), [
        existing.path,
      ]);
    });
  }

  test(
    'reports a filesystem error without truncating the cached file',
    () async {
      await Directory(french.toPath(entry.path)).create();
      await expectLater(
        saveOfflineSubtitles(entry.path, [
          english,
          french,
        ], fetch: (_) async => utf8.encode(fresh)),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(english.toPath(entry.path)).readAsString(), old);
    },
  );
}
