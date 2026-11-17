import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/customer_statement_model.dart';
import '../../providers/customer_statement_providers.dart';

const _blue = Color(0xFF173EB5);
const _page = Color(0xFFF8F9FD);

class CustomerStatementPreviewScreen extends ConsumerWidget {
  const CustomerStatementPreviewScreen({
    required this.customerId,
    required this.startDate,
    required this.endDate,
    super.key,
  });
  final String customerId;
  final DateTime startDate;
  final DateTime endDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (customerId.isEmpty || endDate.isBefore(startDate)) {
      return _ErrorView(
        message: 'The customer or selected date range is invalid.',
        onRetry: context.pop,
      );
    }
    final request = (
      customerId: customerId,
      startDate: startDate,
      endDate: endDate,
    );
    final statementAsync = ref.watch(customerStatementProvider(request));
    return statementAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _page,
        body: Center(child: CircularProgressIndicator(color: _blue)),
      ),
      error: (error, _) => _ErrorView(
        message: error.toString().replaceFirst('Bad state: ', ''),
        onRetry: () => ref.invalidate(customerStatementProvider(request)),
      ),
      data: (statement) => _StatementPreview(statement: statement),
    );
  }
}

class _StatementPreview extends ConsumerWidget {
  const _StatementPreview({required this.statement});
  final CustomerStatementModel statement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generation = ref.watch(statementGenerationProvider);
    final expectedCacheKey =
        '${statement.customerId}:${statement.startDate.toIso8601String()}:${statement.endDate.toIso8601String()}';
    if (generation.status == StatementGenerationStatus.idle ||
        generation.cacheKey != expectedCacheKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(statementGenerationProvider.notifier).generate(statement);
      });
    }
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: const Color(0xFF173EB5),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Customer Statement',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Upload PDF',
            onPressed: generation.isLoading
                ? null
                : () async {
                    final url = await ref
                        .read(statementGenerationProvider.notifier)
                        .upload(statement);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            url == null
                                ? 'Could not upload the PDF.'
                                : 'Statement uploaded securely.',
                          ),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          if (generation.isLoading)
            LinearProgressIndicator(
              value: generation.progress == 0 ? null : generation.progress,
              color: _blue,
            ),
          if (statement.transactions.isEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF4E5),
              padding: const EdgeInsets.all(9),
              child: const Text(
                'No transactions were found in this date range. '
                'The statement still includes opening and closing balances.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9),
              ),
            ),
          Expanded(
            child: generation.errorMessage != null && generation.bytes == null
                ? _PdfError(
                    message: generation.errorMessage!,
                    onRetry: () {
                      ref.read(statementGenerationProvider.notifier).reset();
                      ref
                          .read(statementGenerationProvider.notifier)
                          .generate(statement);
                    },
                  )
                : generation.bytes == null
                ? const Center(child: CircularProgressIndicator(color: _blue))
                : PdfPreview(
                    build: (_) async => generation.bytes!,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    allowPrinting: false,
                    allowSharing: false,
                    pdfFileName: '${statement.customer.name}_statement.pdf',
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _Action(
                icon: Icons.download_outlined,
                label: 'Download',
                onTap: generation.isLoading
                    ? null
                    : () => _download(context, ref),
              ),
              _Action(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: generation.bytes == null
                    ? null
                    : () => Printing.sharePdf(
                        bytes: generation.bytes!,
                        filename: '${statement.customer.name}_statement.pdf',
                      ),
              ),
              _Action(
                icon: Icons.print_outlined,
                label: 'Print',
                onTap: generation.bytes == null
                    ? null
                    : () => Printing.layoutPdf(
                        onLayout: (_) async => generation.bytes!,
                        name: '${statement.customer.name} Statement',
                      ),
              ),
              _Action(
                icon: Icons.chat_outlined,
                label: 'WhatsApp',
                onTap: generation.isLoading
                    ? null
                    : () => _whatsApp(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final file = await ref
        .read(statementGenerationProvider.notifier)
        .save(statement);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          file == null ? 'Could not save the PDF.' : 'Saved to ${file.path}',
        ),
      ),
    );
  }

  Future<void> _whatsApp(BuildContext context, WidgetRef ref) async {
    final file = await ref
        .read(statementGenerationProvider.notifier)
        .save(statement);
    if (file == null || !context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Smart Khata statement for ${statement.customer.name}, '
            '${DateFormat('dd MMM yyyy').format(statement.startDate)} - '
            '${DateFormat('dd MMM yyyy').format(statement.endDate)}. '
            'Choose WhatsApp to send it.',
        files: [XFile(file.path, mimeType: 'application/pdf')],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: TextButton(
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 8)),
        ],
      ),
    ),
  );
}

class _PdfError extends StatelessWidget {
  const _PdfError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 10),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: context.pop,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Customer Statement'),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );
}
