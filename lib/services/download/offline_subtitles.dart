import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/models_new/video/video_play_info/subtitle.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:path/path.dart' as path;

/// Prepare the entire set before replacing any previously playable caption.
Future<List<LocalSubtitle>> saveOfflineSubtitles(
  String entryDir,
  List<Subtitle> subtitles, {
  required Future<List<int>?> Function(String) fetch,
}) async {
  final directory = Directory(path.join(entryDir, PathUtils.subtitleDir));
  await directory.create(recursive: true);
  final staging = await directory.createTemp('.refresh-');
  try {
    final staged = <String, File>{};
    final local = <LocalSubtitle>[];
    for (final subtitle in subtitles) {
      final url = subtitle.subtitleUrl;
      final target = subtitle.toLocal(entryDir);
      if (url == null || url.isEmpty || staged.containsKey(target.path)) {
        throw const FormatException('Missing or ambiguous caption source');
      }
      final bytes = await fetch(url);
      if (bytes == null) throw const FormatException('Missing offline caption');
      final payload = jsonDecode(utf8.decode(bytes));
      if (payload is! Map ||
          payload['body'] is! List ||
          !(payload['body'] as List).every(_isCaptionCue)) {
        throw const FormatException('Invalid offline caption');
      }
      final file = File(path.join(staging.path, path.basename(target.path)));
      await file.writeAsBytes(bytes, flush: true);
      staged[target.path] = file;
      local.add(target);
    }
    final replaced = <File, File?>{};
    try {
      for (final file in staged.entries) {
        final destination = File(file.key);
        final backup = await destination.exists()
            ? await destination.copy('${file.value.path}.previous')
            : null;
        await file.value.rename(file.key);
        replaced[destination] = backup;
      }
    } on FileSystemException {
      for (final track in replaced.entries) {
        if (track.value case final backup?) {
          await backup.rename(track.key.path);
        } else {
          await track.key.delete();
        }
      }
      rethrow;
    }
    return local;
  } finally {
    await staging.delete(recursive: true);
  }
}

bool _isCaptionCue(dynamic cue) => switch (cue) {
  {'from': num _, 'to': num _, 'content': String _} => true,
  _ => false,
};
