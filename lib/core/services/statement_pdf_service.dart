import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/customer_statement_model.dart';

class StatementPdfService {
  Future<Uint8List> generate(CustomerStatementModel statement) async {
    final document = pw.Document();
    pw.ImageProvider? logo;
    if (statement.business.logoUrl.isNotEmpty) {
      try {
        logo = await networkImage(statement.business.logoUrl);
      } catch (_) {}
    }
    final money = NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 2,
    );
    final date = DateFormat('dd MMM yyyy');
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(
                width: 48,
                height: 48,
                margin: const pw.EdgeInsets.only(right: 12),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    statement.business.name,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(statement.business.ownerName),
                  pw.Text(
                    '${statement.business.address}, ${statement.business.city}',
                  ),
                  pw.Text(statement.business.phone),
                ],
              ),
            ),
            pw.Text(
              'CUSTOMER STATEMENT',
              style: pw.TextStyle(
                color: PdfColors.blue800,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        build: (_) => [
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      statement.customer.name,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(statement.customer.phone),
                    pw.Text(statement.customer.address),
                  ],
                ),
                pw.Text(
                  '${date.format(statement.startDate)} - '
                  '${date.format(statement.endDate)}',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 15),
          if (statement.transactions.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(30),
              child: pw.Center(
                child: pw.Text('No transactions in the selected date range.'),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Date',
                'Description',
                'You Gave',
                'You Received',
                'Balance',
              ],
              data: statement.transactions
                  .map(
                    (item) => [
                      date.format(item.transactionDate),
                      item.description.isEmpty
                          ? item.paymentMethod
                          : item.description,
                      item.transactionType == 'gave'
                          ? money.format(item.amount)
                          : '-',
                      item.transactionType != 'gave'
                          ? money.format(item.amount)
                          : '-',
                      money.format(item.updatedBalance),
                    ],
                  )
                  .toList(),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue800,
              ),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          pw.SizedBox(height: 18),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 250,
                child: pw.Column(
                  children: [
                    _total(
                      'Opening Balance',
                      money.format(statement.openingBalance),
                    ),
                    _total('Total You Gave', money.format(statement.totalGave)),
                    _total(
                      'Total You Received',
                      money.format(statement.totalReceived),
                    ),
                    pw.Divider(),
                    _total(
                      'Closing Balance',
                      money.format(statement.closingBalance),
                      bold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Generated by Smart Khata • Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
      ),
    );
    return document.save();
  }

  pw.Widget _total(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label),
            pw.Text(
              value,
              style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
            ),
          ],
        ),
      );

  Future<File> saveLocally(
    Uint8List bytes,
    CustomerStatementModel statement,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeName = statement.customer.name.replaceAll(
      RegExp(r'[^A-Za-z0-9]+'),
      '_',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}${safeName}_statement_${DateFormat('yyyyMMdd').format(statement.endDate)}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
