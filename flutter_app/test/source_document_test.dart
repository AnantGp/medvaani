import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_cdss/source_document.dart';

void main() {
  test('source content determines PDF and photo rendering, even if misnamed',
      () {
    final samples = <String, List<int>>{
      'application/pdf': ascii.encode('%PDF-1.7\n'),
      'image/png': [137, 80, 78, 71, 13, 10, 26, 10, 0],
      'image/jpeg': [255, 216, 255, 224, 0, 16],
      'image/webp': [82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80]
    };
    for (final entry in samples.entries) {
      expect(sourceMimeType(Uint8List.fromList(entry.value)), entry.key);
    }
    expect(
        sourceMimeType(Uint8List.fromList(ascii.encode('not a PDF'))), isNull);
    expect(sourceMimeType(Uint8List(0)), isNull);
    expect(sourceUploadName('camera.pdf', 'image/png'), 'camera.png');
    expect(sourceUploadName('report', 'application/pdf'), 'report.pdf');
    expect(sourceUploadName('camera.JPEG', 'image/jpeg'), 'camera.JPEG');
  });
}
