import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/statement_pdf_service.dart';
import '../models/customer_statement_model.dart';
import 'business_providers.dart';
import 'app_providers.dart';

typedef StatementRequest = ({
  String customerId,
  DateTime startDate,
  DateTime endDate,
});

final statementPdfServiceProvider = Provider((_) => StatementPdfService());

final customerStatementProvider =
    FutureProvider.family<CustomerStatementModel, StatementRequest>((
      ref,
      request,
    ) async {
      final user = ref.watch(currentUserProvider);
      final business = await ref.watch(currentBusinessProvider.future);
      if (user == null || business == null || business.ownerId != user.uid) {
        throw StateError('Authentication or business access was denied.');
      }
      return ref
          .watch(customerStatementRepositoryProvider)
          .load(
            ownerId: user.uid,
            businessId: business.id,
            customerId: request.customerId,
            startDate: request.startDate,
            endDate: request.endDate,
          );
    });

enum StatementGenerationStatus {
  idle,
  generating,
  ready,
  saving,
  uploading,
  error,
}

class StatementGenerationState {
  const StatementGenerationState({
    this.status = StatementGenerationStatus.idle,
    this.progress = 0,
    this.bytes,
    this.file,
    this.uploadedUrl,
    this.errorMessage,
    this.cacheKey,
  });
  final StatementGenerationStatus status;
  final double progress;
  final Uint8List? bytes;
  final File? file;
  final String? uploadedUrl;
  final String? errorMessage;
  final String? cacheKey;
  bool get isLoading =>
      status == StatementGenerationStatus.generating ||
      status == StatementGenerationStatus.saving ||
      status == StatementGenerationStatus.uploading;
}

final statementGenerationProvider =
    NotifierProvider<StatementGenerationNotifier, StatementGenerationState>(
      StatementGenerationNotifier.new,
    );

class StatementGenerationNotifier extends Notifier<StatementGenerationState> {
  @override
  StatementGenerationState build() => const StatementGenerationState();

  Future<Uint8List?> generate(CustomerStatementModel statement) async {
    final cacheKey =
        '${statement.customerId}:${statement.startDate.toIso8601String()}:${statement.endDate.toIso8601String()}';
    if (state.status == StatementGenerationStatus.generating) return null;
    if (state.bytes != null && state.cacheKey == cacheKey) return state.bytes;
    state = StatementGenerationState(
      status: StatementGenerationStatus.generating,
      progress: .2,
      cacheKey: cacheKey,
    );
    try {
      final bytes = await ref
          .read(statementPdfServiceProvider)
          .generate(statement);
      state = StatementGenerationState(
        status: StatementGenerationStatus.ready,
        progress: 1,
        bytes: bytes,
        cacheKey: cacheKey,
      );
      return bytes;
    } catch (_) {
      state = const StatementGenerationState(
        status: StatementGenerationStatus.error,
        errorMessage: 'Could not generate the statement PDF.',
      );
      return null;
    }
  }

  Future<File?> save(CustomerStatementModel statement) async {
    final bytes = await generate(statement);
    if (bytes == null) return null;
    state = StatementGenerationState(
      status: StatementGenerationStatus.saving,
      progress: .8,
      bytes: bytes,
    );
    try {
      final file = await ref
          .read(statementPdfServiceProvider)
          .saveLocally(bytes, statement);
      state = StatementGenerationState(
        status: StatementGenerationStatus.ready,
        progress: 1,
        bytes: bytes,
        file: file,
        cacheKey: state.cacheKey,
      );
      return file;
    } catch (_) {
      state = StatementGenerationState(
        status: StatementGenerationStatus.error,
        bytes: bytes,
        errorMessage: 'Could not save the PDF on this device.',
      );
      return null;
    }
  }

  Future<String?> upload(CustomerStatementModel statement) async {
    final user = ref.read(currentUserProvider);
    final business = ref.read(currentBusinessProvider).value;
    final bytes = await generate(statement);
    if (user == null || business == null || bytes == null) return null;
    state = StatementGenerationState(
      status: StatementGenerationStatus.uploading,
      progress: .7,
      bytes: bytes,
    );
    try {
      final url = await ref
          .read(storageRepositoryProvider)
          .uploadData(
            path:
                'users/${user.uid}/businesses/${business.id}/statements/${statement.customerId}_${statement.startDate.millisecondsSinceEpoch}_${statement.endDate.millisecondsSinceEpoch}.pdf',
            data: bytes,
          );
      state = StatementGenerationState(
        status: StatementGenerationStatus.ready,
        progress: 1,
        bytes: bytes,
        uploadedUrl: url,
        cacheKey: state.cacheKey,
      );
      return url;
    } catch (_) {
      state = StatementGenerationState(
        status: StatementGenerationStatus.error,
        bytes: bytes,
        errorMessage: 'Could not upload this PDF.',
      );
      return null;
    }
  }

  void reset() => state = const StatementGenerationState();
}
