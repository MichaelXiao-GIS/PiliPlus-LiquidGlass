import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/grpc/bilibili/im/interfaces/v1.pb.dart'
    show EmotionInfo;
import 'package:PiliPlus/pages/whisper_detail/message_emotes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'chat pages share a matcher and preserve the first emote definition',
    () {
      final emotes = MessageEmotes();
      final first = EmotionInfo(text: '[a+b]', gifUrl: 'animated');
      emotes.addAll([first]);
      final matcher = emotes.pattern;
      emotes.addAll([
        EmotionInfo(text: '[a+b]', url: 'duplicate'),
        EmotionInfo(),
      ]);
      expect(emotes.pattern, same(matcher));
      expect(emotes['[a+b]'], same(first));

      emotes.addAll([EmotionInfo(text: '[new]')]);
      expect(
        emotes.pattern
            .allMatches('https://example.com [a+b] [new] [aaab]')
            .map((match) => match[0]),
        ['https://example.com', '[a+b]', '[new]'],
      );

      emotes.clear();
      expect(emotes['[a+b]'], isNull);
      expect(emotes.pattern, same(Constants.urlRegex));
    },
  );
}
