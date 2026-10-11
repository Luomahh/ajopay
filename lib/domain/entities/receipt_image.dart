import 'dart:typed_data';

class ReceiptImage {
  const ReceiptImage(this.bytes, this.extension, this.contentType);
  final Uint8List bytes;
  final String extension, contentType;
  static ReceiptImage? parse(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) return null;
    if (bytes.length >= 8 &&
        [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ].asMap().entries.every((e) => bytes[e.key] == e.value)) {
      return ReceiptImage(bytes, 'png', 'image/png');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return ReceiptImage(bytes, 'jpg', 'image/jpeg');
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return ReceiptImage(bytes, 'webp', 'image/webp');
    }
    return null;
  }
}
