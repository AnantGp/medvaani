import 'dart:typed_data';

/// Read the actual signature; a camera file can have a missing/wrong suffix.
String? sourceMimeType(Uint8List bytes) {
  bool at(List<int> signature, [int offset = 0]) =>
      bytes.length >= offset + signature.length &&
      List.generate(signature.length, (i) => i)
          .every((i) => bytes[offset + i] == signature[i]);
  if (at([0x25, 0x50, 0x44, 0x46, 0x2d])) return 'application/pdf';
  if (at([137, 80, 78, 71, 13, 10, 26, 10])) return 'image/png';
  if (at([255, 216, 255])) return 'image/jpeg';
  if (at([82, 73, 70, 70]) && at([87, 69, 66, 80], 8)) {
    return 'image/webp';
  }
  return null;
}

String sourceUploadName(String name, String mime) {
  final extension = {
    'application/pdf': 'pdf',
    'image/png': 'png',
    'image/jpeg': 'jpg',
    'image/webp': 'webp'
  }[mime]!;
  final suffix = name.split('.').last.toLowerCase();
  if (suffix == extension || (extension == 'jpg' && suffix == 'jpeg')) {
    return name;
  }
  final stem =
      name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
  return '${stem.isEmpty ? 'report' : stem}.$extension';
}
