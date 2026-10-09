import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/features/capture/capture_api.dart';
import 'package:nexus_mobile/features/capture/capture_screen.dart';

void main() {
  test('isbnFromBarcode accepts Bookland EAN-13 and ISBN-10 only', () {
    expect(isbnFromBarcode('9780812981605'), '9780812981605');
    expect(isbnFromBarcode('979-1-0000-0000-1'), '9791000000001');
    expect(isbnFromBarcode('080442957x'), '080442957X');
    expect(isbnFromBarcode('5000112637922'), isNull);
    expect(isbnFromBarcode('12345'), isNull);
    expect(isbnFromBarcode(null), isNull);
  });

  test('CaptureMode maps route params', () {
    expect(CaptureMode.from('wine'), CaptureMode.wine);
    expect(CaptureMode.from('book', barcode: true), CaptureMode.barcode);
    expect(CaptureMode.from('nonsense'), CaptureMode.auto);
    expect(CaptureMode.from(null), CaptureMode.auto);
  });

  test('CaptureResult reads the identify payload', () {
    final r = CaptureResult.fromJson({
      'media': {'id': 42, 'public_id': 'nexus/capture/abc'},
      'identification': {
        'kind': 'beer',
        'confidence': 0.91,
        'fields': {'name': 'Lager', 'abv': 4.5},
      },
    });
    expect(r.kind, 'beer');
    expect(r.mediaId, 42);
    expect(r.confidence, closeTo(.91, 1e-9));
    expect(r.fields['name'], 'Lager');
    expect(CaptureResult.fromJson(const {}).kind, 'unknown');
  });
}
