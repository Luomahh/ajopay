import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/savings_group.dart';

String nigeriaTimestamp(String value) {
  final d = DateTime.parse(value).toUtc().add(const Duration(hours: 1));
  return '${dateOnly(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String statementStatus(String status) => switch (status) {
  'pending' => 'Awaiting leader review',
  'confirmed' => 'Confirmed',
  'rejected' => 'Needs correction',
  'reported' => 'Awaiting recipient',
  'disputed' => 'Problem reported',
  _ => status,
};

/// Contains only the server-scoped payment snapshot. No profile contact or identity data.
Future<Uint8List> buildStatementPdf(
  Map<String, dynamic> data, {
  required ByteData regularFont,
  required ByteData boldFont,
}) async {
  final regular = pw.Font.ttf(regularFont), bold = pw.Font.ttf(boldFont);
  final doc = pw.Document(title: 'AjoPay payment statement', author: 'AjoPay');
  final entries = (data['entries'] as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
  final fees = (data['late_fees'] as List? ?? [])
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
  int total(String kind) => entries
      .where((r) => r['kind'] == kind && r['status'] == 'confirmed')
      .fold(0, (sum, r) => sum + (r['amount_kobo'] as int));
  final forest = PdfColor.fromHex('#123F35'),
      mint = PdfColor.fromHex('#D9F3E5');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(32),
      maxPages: 2000,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: forest)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'ajopay',
              style: pw.TextStyle(
                color: forest,
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'PAYMENT RECORDS',
              style: pw.TextStyle(color: forest, fontSize: 10),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Private group record - not a bank statement',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.SizedBox(height: 12),
        pw.Text(
          data['group_name'] as String,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: forest,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          '${data['scope']} | Group status: ${data['group_status']}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          'Generated ${nigeriaTimestamp(data['generated_at'] as String)} WAT (Nigeria)',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.Text(
          'Payment dates: ${data['from_date'] ?? 'all'} to ${data['to_date'] ?? 'all'}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          color: mint,
          padding: const pw.EdgeInsets.all(12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Confirmed contributions: ${formatNaira(total('contribution'))}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Acknowledged payouts: ${formatNaira(total('payout'))}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Latest status of each recorded payment within this date range. Pending, returned and disputed amounts are excluded from confirmed totals. These are external transfers reported by members and reviewed by the group; AjoPay has not verified bank settlement.',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 12),
        if (entries.isEmpty)
          pw.Text('No payment records in this date range.')
        else
          pw.TableHelper.fromTextArray(
            headers: [
              'Payment date',
              'Recorded (WAT)',
              'Member',
              'Type / period',
              'Amount (NGN)',
              'Status',
              'Reference',
            ],
            data: entries
                .map(
                  (r) => [
                    r['paid_on'],
                    nigeriaTimestamp(r['recorded_at'] as String),
                    r['member_name'],
                    '${r['kind']} / ${r['period'] == 0 ? 'end date' : r['period']}',
                    formatNaira(
                      r['amount_kobo'] as int,
                    ).replaceFirst('NGN ', ''),
                    statementStatus(r['status'] as String),
                    r['reference'],
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              font: bold,
              fontSize: 9,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: forest),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.all(6),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .4),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(1.3),
              2: const pw.FlexColumnWidth(1.4),
              3: const pw.FlexColumnWidth(1.1),
              4: const pw.FlexColumnWidth(1.1),
              5: const pw.FlexColumnWidth(1.4),
              6: const pw.FlexColumnWidth(1.8),
            },
          ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Late-fee assessment - not collected',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Fees belong to AjoPay separately from savings. Collection is not enabled. Unconfirmed payment dates may change this assessment after leader review.',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 6),
        if (fees.isEmpty)
          pw.Text(
            'No late fees listed for this date range.',
            style: const pw.TextStyle(fontSize: 9),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: [
              'Member ID',
              'Period',
              'Deadline',
              'Fee (NGN)',
              'Assessment',
            ],
            data: fees
                .map(
                  (r) => [
                    r['user_id'],
                    r['period_number'],
                    r['due_date'],
                    formatNaira(
                      r['amount_kobo'] as int,
                    ).replaceFirst('NGN ', ''),
                    r['status'] == 'due'
                        ? 'Due - not collected'
                        : 'Payment date awaiting review',
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(font: bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.all(5),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .4),
          ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Keep this file private. It contains payment references and member names. Addresses, phone numbers, BVN/NIN, screenshots and private notes are not included. Recorded time is when a report was submitted, not the bank transfer time.',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    ),
  );
  return doc.save();
}
