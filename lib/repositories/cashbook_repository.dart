import '../core/database/hive_database.dart';
import '../models/cashbook_entry_model.dart';
import 'search_repository.dart';

class CashbookRepository {
  CashbookRepository();

  Stream<List<CashbookEntryModel>> watch(String ownerId, String businessId) {
    final box = HiveDatabase.instance.cashbookBox;
    return Stream.multi((controller) {
      void emit() {
        if (controller.isClosed) return;
        final entries = box.values
            .map((e) =>
                CashbookEntryModel.fromMap(Map<String, dynamic>.from(e), e['id']))
            .where((c) => c.ownerId == ownerId && c.businessId == businessId)
            .toList();
        entries.sort((a, b) => b.entryDate.compareTo(a.entryDate));
        controller.add(entries);
      }

      emit();
      final sub = box.watch().listen((_) => emit());
      controller.onCancel = () => sub.cancel();
    });
  }

  Stream<CashbookEntryModel?> watchById({
    required String entryId,
    required String ownerId,
    required String businessId,
  }) {
    final box = HiveDatabase.instance.cashbookBox;
    return Stream.multi((controller) {
      void emit() {
        if (controller.isClosed) return;
        final data = box.get(entryId);
        if (data == null) {
          controller.add(null);
          return;
        }
        final entry =
            CashbookEntryModel.fromMap(Map<String, dynamic>.from(data), entryId);
        if (entry.ownerId != ownerId || entry.businessId != businessId) {
          controller.addError(
            StateError('You do not have permission to view this cash entry.'),
          );
          return;
        }
        controller.add(entry);
      }

      emit();
      final sub = box.watch(key: entryId).listen((_) => emit());
      controller.onCancel = () => sub.cancel();
    });
  }

  Future<CashbookEntryModel> create(CashbookEntryModel entry) async {
    if (!entry.amount.isFinite || entry.amount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }

    final cashBox = HiveDatabase.instance.cashbookBox;
    final bizBox = HiveDatabase.instance.businessesBox;

    final bizData = bizBox.get(entry.businessId);
    if (bizData == null) {
      throw StateError('Business was not found.');
    }

    final id = entry.id.isNotEmpty
        ? entry.id
        : 'cash_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();

    final map = entry.toMap()
      ..['id'] = id
      ..['descriptionNormalized'] = normalizeSearchText(entry.description)
      ..['categoryNormalized'] = normalizeSearchText(entry.category)
      ..['createdAt'] = now
      ..['updatedAt'] = now;
    await cashBox.put(id, map);

    final signedAmount = entry.isCashIn ? entry.amount : -entry.amount;
    final biz = Map<String, dynamic>.from(bizData);
    biz['cashBalance'] =
        (biz['cashBalance'] as num? ?? 0).toDouble() + signedAmount;
    if (entry.isCashIn) {
      biz['totalCashIn'] =
          (biz['totalCashIn'] as num? ?? 0).toDouble() + entry.amount;
    } else {
      biz['totalCashOut'] =
          (biz['totalCashOut'] as num? ?? 0).toDouble() + entry.amount;
    }
    biz['updatedAt'] = now;
    await bizBox.put(entry.businessId, biz);

    return CashbookEntryModel(
      id: id,
      ownerId: entry.ownerId,
      businessId: entry.businessId,
      type: entry.type,
      amount: entry.amount,
      category: entry.category,
      description: entry.description,
      paymentMethod: entry.paymentMethod,
      receiptUrl: entry.receiptUrl,
      entryDate: entry.entryDate,
    );
  }

  Future<void> update(CashbookEntryModel edited) async {
    if (!edited.amount.isFinite || edited.amount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }

    final cashBox = HiveDatabase.instance.cashbookBox;
    final bizBox = HiveDatabase.instance.businessesBox;

    final oldData = cashBox.get(edited.id);
    final bizData = bizBox.get(edited.businessId);
    if (oldData == null || bizData == null) {
      throw StateError('Cash entry or business not found.');
    }

    final old =
        CashbookEntryModel.fromMap(Map<String, dynamic>.from(oldData), edited.id);
    final oldSigned = old.isCashIn ? old.amount : -old.amount;
    final newSigned = edited.isCashIn ? edited.amount : -edited.amount;

    final now = DateTime.now().toIso8601String();
    final map = edited.toMap()
      ..['id'] = edited.id
      ..['categoryNormalized'] = normalizeSearchText(edited.category)
      ..['descriptionNormalized'] = normalizeSearchText(edited.description)
      ..['updatedAt'] = now;
    await cashBox.put(edited.id, map);

    final biz = Map<String, dynamic>.from(bizData);
    biz['cashBalance'] =
        (biz['cashBalance'] as num? ?? 0).toDouble() + (newSigned - oldSigned);
    biz['totalCashIn'] = (biz['totalCashIn'] as num? ?? 0).toDouble() +
        ((edited.isCashIn ? edited.amount : 0) - (old.isCashIn ? old.amount : 0));
    biz['totalCashOut'] = (biz['totalCashOut'] as num? ?? 0).toDouble() +
        ((!edited.isCashIn ? edited.amount : 0) - (!old.isCashIn ? old.amount : 0));
    biz['updatedAt'] = now;
    await bizBox.put(edited.businessId, biz);
  }

  Future<void> delete(CashbookEntryModel entry) async {
    final cashBox = HiveDatabase.instance.cashbookBox;
    final bizBox = HiveDatabase.instance.businessesBox;

    final oldData = cashBox.get(entry.id);
    final bizData = bizBox.get(entry.businessId);
    if (oldData == null || bizData == null) {
      throw StateError('Cash entry or business not found.');
    }

    final saved =
        CashbookEntryModel.fromMap(Map<String, dynamic>.from(oldData), entry.id);
    await cashBox.delete(entry.id);

    final now = DateTime.now().toIso8601String();
    final biz = Map<String, dynamic>.from(bizData);
    biz['cashBalance'] = (biz['cashBalance'] as num? ?? 0).toDouble() +
        (saved.isCashIn ? -saved.amount : saved.amount);
    if (saved.isCashIn) {
      biz['totalCashIn'] =
          (biz['totalCashIn'] as num? ?? 0).toDouble() - saved.amount;
    } else {
      biz['totalCashOut'] =
          (biz['totalCashOut'] as num? ?? 0).toDouble() - saved.amount;
    }
    biz['updatedAt'] = now;
    await bizBox.put(entry.businessId, biz);
  }
}
