import 'dart:io';
import 'dart:typed_data';
import 'package:ajopay/features/statements/statement_pdf.dart';
import 'package:ajopay/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Nigerian phone normalization and invalid contact validation', () {
    expect(Validators.normalizePhone('080 1234 5678'), '+2348012345678');
    expect(Validators.phone('08012345678'), isNull);
    expect(Validators.phone(''), isNotNull);
    expect(Validators.phone('not a number'), isNotNull);
  });
  test('record time uses Nigeria date across UTC midnight boundary', () {
    expect(nigeriaTimestamp('2026-10-11T23:30:00Z'), '2026-10-12 00:30');
  });
  test('statement renders multiple pages with long references', () async {
    final bytes = await buildStatementPdf(
      {
        'group_name': 'Sample community savings — fictional records',
        'group_status': 'active',
        'scope': 'Group leader - all members',
        'generated_at': '2026-10-12T10:15:00Z',
        'from_date': '2026-10-01',
        'to_date': '2026-10-12',
        'entries': List.generate(
          45,
          (i) => {
            'kind': i % 3 == 0 ? 'payout' : 'contribution',
            'member_name': 'Sample Member ${i + 1}',
            'period': i + 1,
            'paid_on': '2026-10-12',
            'recorded_at': '2026-10-12T09:30:00Z',
            'amount_kobo': 1000000,
            'status': i % 2 == 0 ? 'confirmed' : 'pending',
            'reference': 'DEMO-REFERENCE-${i + 1}-NOT-A-REAL-TRANSFER',
          },
        ),
        'late_fees': [],
      },
      regularFont: ByteData.sublistView(
        File('assets/fonts/Lato-Regular.ttf').readAsBytesSync(),
      ),
      boldFont: ByteData.sublistView(
        File('assets/fonts/Lato-Bold.ttf').readAsBytesSync(),
      ),
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    final output = Platform.environment['AJO_STATEMENT_SAMPLE'];
    if (output != null) File(output).writeAsBytesSync(bytes);
  });
}
