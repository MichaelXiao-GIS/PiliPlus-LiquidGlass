import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _Defaults extends Fake implements Box<dynamic> {
  final _values = <dynamic, dynamic>{};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _values[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _values[key] = value;
  }
}

void main() {
  const image = 'https://i0.hdslb.com/bfs/archive/cover.jpg';
  String preview(String url, {int width = 510, bool crop = true}) =>
      ImageUtils.feedThumbnailUrl(
        url,
        pixelWidth: width,
        aspectRatio: 16 / 9,
        centerCrop: crop,
        minQuality: 40,
      );

  setUpAll(() {
    GStorage.setting = _Defaults();
    GStorage.localCache = _Defaults();
  });

  test('CDN cover matches the card and reuses nearby widths', () {
    expect(preview(image), '$image@512w_288h_1c_40q.webp');
    expect(preview(image, width: 500), preview(image, width: 512));
    expect(preview(image, width: 513), '$image@576w_324h_1c_40q.webp');
    expect(preview(image.replaceFirst('https:', '')), preview(image));
  });

  test('top-aligned post previews preserve the full image proportions', () {
    const post = 'https://i2.hdslb.com/bfs/new_dyn/photo.png';
    expect(preview(post, crop: false), '$post@512w_40q.webp');
  });

  test('signed URLs and explicit original-size images keep their source', () {
    for (final url in ['$image?token=ab%2Bcd', '$image#frame']) {
      expect(preview(url), url);
    }
    expect(
      ImageUtils.feedThumbnailUrl(
        image,
        pixelWidth: 400,
        aspectRatio: 1,
        centerCrop: true,
        minQuality: 100,
      ),
      image,
    );
  });

  test('legacy variants and other image services keep their existing URLs', () {
    for (final url in [
      '$image@160w_100h_1c.webp',
      image.replaceFirst('archive', 'face'),
      image.replaceFirst('.jpg', '.gif'),
      image.replaceFirst('i0.hdslb.com', 'example.com'),
    ]) {
      expect(preview(url), ImageUtils.thumbnailUrl(url, 40));
    }
    expect(preview(image, width: 0), ImageUtils.thumbnailUrl(image, 40));
    expect(preview(image, width: 5000), ImageUtils.thumbnailUrl(image, 40));
  });

  testWidgets('a failed sized cover can use the previous disk-cache URL once', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 2),
        child: Builder(
          builder: (childContext) {
            context = childContext;
            return const SizedBox();
          },
        ),
      ),
    );
    final clip = const NetworkImgLayer(
      src: image,
      width: 240,
      height: 135,
      quality: 40,
      feedThumbnail: true,
    ).build(context) as ClipRRect;
    final cover = clip.child! as CachedNetworkImage;
    expect(cover.imageUrl, '$image@512w_288h_1c_40q.webp');
    final fallback = cover.errorBuilder!(
      context,
      StateError('offline'),
      null,
    ) as CachedNetworkImage;
    expect(fallback.imageUrl, ImageUtils.thumbnailUrl(image, 40));
    expect(
      fallback.errorBuilder!(context, StateError('offline'), null),
      isNot(isA<CachedNetworkImage>()),
    );
  });
}
