import 'dart:convert';
import 'dart:typed_data';
import 'package:ajopay/domain/entities/receipt_image.dart';
import 'package:ajopay/domain/entities/contribution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'receipt picker accepts PNG bytes and rejects unsupported/oversized content',
    () {
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
      );
      expect(ReceiptImage.parse(png)!.contentType, 'image/png');
      expect(
        ReceiptImage.parse(Uint8List.fromList('not an image'.codeUnits)),
        isNull,
      );
      expect(ReceiptImage.parse(Uint8List(5242881)), isNull);
    },
  );
  test('payment evidence decodes separately from reviewer note', () {
    final c = Contribution.fromJson({
      'user_id': 'member',
      'period_number': 1,
      'amount_kobo': 1000000,
      'payment_reference': 'ref',
      'paid_on': '2026-10-10',
      'status': 'rejected',
      'version': 1,
      'review_note': 'Check date',
      'payment_note': 'Paid Thursday',
      'receipt_path': 'group/member/file.png',
    });
    expect(c.note, 'Check date');
    expect(c.paymentNote, 'Paid Thursday');
    expect(c.receiptPath, 'group/member/file.png');
  });
}
