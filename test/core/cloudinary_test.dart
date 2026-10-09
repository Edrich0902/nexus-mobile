import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/core/media/cloudinary.dart';
import 'package:nexus_mobile/core/media/media_image.dart';

void main() {
  group('CloudinaryDelivery', () {
    final cdn = CloudinaryDelivery('nexus-hub');

    test('builds secure named-transform URLs from a public id', () {
      final url = cdn.url(const MediaImage(publicId: 'nexus/cellar/abc123'), MediaVariant.card)!;
      expect(url, startsWith('https://res.cloudinary.com/nexus-hub/image/upload/'));
      expect(url, contains('t_nexus_card'));
      expect(url, endsWith('nexus/cellar/abc123'));
      expect(url, isNot(contains('_a=')), reason: 'analytics params are disabled');
      expect(url, isNot(matches(RegExp(r'/(w|h|c)_\d'))), reason: 'Strict mode allows named transforms only');
    });

    test('falls back to rewriting a stored secure_url', () {
      const stored = 'https://res.cloudinary.com/nexus-hub/image/upload/v17/nexus/x.jpg';
      expect(
        cdn.url(const MediaImage(url: stored), MediaVariant.thumb),
        'https://res.cloudinary.com/nexus-hub/image/upload/t_nexus_thumb/v17/nexus/x.jpg',
      );
    });

    test('swaps an existing named transform instead of stacking', () {
      const stored = 'https://res.cloudinary.com/nexus-hub/image/upload/t_nexus_master/v1/a.jpg';
      expect(
        CloudinaryDelivery.rewriteUrl(stored, MediaVariant.hero),
        'https://res.cloudinary.com/nexus-hub/image/upload/t_nexus_hero/v1/a.jpg',
      );
    });

    test('leaves third-party URLs untouched', () {
      const spotify = 'https://i.scdn.co/image/ab67616d0000b273';
      expect(cdn.url(const MediaImage(url: spotify), MediaVariant.card), spotify);
    });

    test('without a cloud name it still rewrites stored URLs', () {
      final none = CloudinaryDelivery(null);
      expect(none.enabled, isFalse);
      expect(none.url(const MediaImage(publicId: 'a'), MediaVariant.card), isNull);
    });
  });

  group('MediaVariant.forBox', () {
    test('picks by physical pixels', () {
      expect(MediaVariant.forBox(width: 48, height: 48, devicePixelRatio: 3), MediaVariant.thumb);
      expect(MediaVariant.forBox(width: 120, height: 120, devicePixelRatio: 3), MediaVariant.thumbHd);
      expect(MediaVariant.forBox(width: 170, height: 113, devicePixelRatio: 2), MediaVariant.card);
      expect(MediaVariant.forBox(width: 300, height: 200, devicePixelRatio: 3), MediaVariant.cardHd);
      expect(MediaVariant.forBox(width: 400, height: 260, devicePixelRatio: 3), MediaVariant.hero);
      expect(MediaVariant.forBox(width: 400, height: 400, devicePixelRatio: 3, avatar: true), MediaVariant.avatar);
    });

    test('never crops art to a shape its box does not have', () {
      // A bottle in a tall print panel: the 3:2 card crop took off its neck.
      expect(MediaVariant.forBox(width: 120, height: 280, devicePixelRatio: 3), MediaVariant.hero);
      // A 3:4 grid tile.
      expect(MediaVariant.forBox(width: 174, height: 232, devicePixelRatio: 3), MediaVariant.hero);
      // Contained art shows the whole image, so any crop is visible.
      expect(
        MediaVariant.forBox(width: 300, height: 200, devicePixelRatio: 3, fit: BoxFit.contain),
        MediaVariant.hero,
      );
      expect(MediaVariant.forBox(width: 300, height: double.infinity, devicePixelRatio: 3), MediaVariant.hero);
    });
  });
}
