import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/grpc/bilibili/im/interfaces/v1.pb.dart'
    show EmotionInfo;

class MessageEmotes {
  final _byText = <String, EmotionInfo>{};
  RegExp? _pattern;

  EmotionInfo? operator [](String text) => _byText[text];

  RegExp get pattern => _pattern ??= _byText.isEmpty
      ? Constants.urlRegex
      : RegExp(
          [
            Constants.urlRegex.pattern,
            ..._byText.keys.map(RegExp.escape),
          ].join('|'),
        );

  void addAll(Iterable<EmotionInfo> entries) {
    for (final entry in entries) {
      if (entry.text.isEmpty || _byText.containsKey(entry.text)) continue;
      _byText[entry.text] = entry;
      _pattern = null;
    }
  }

  void clear() {
    _byText.clear();
    _pattern = null;
  }
}
