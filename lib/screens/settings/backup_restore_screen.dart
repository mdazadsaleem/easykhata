import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/backup_metadata_model.dart';
import '../../models/backup_model.dart';
import '../../providers/backup_providers.dart';

const _blue = Color(0xFF123EAD);
const _green = Color(0xFF008B67);
const _red = Color(0xFFD71920);
const _muted = Color(0xFF667085);
const _page = Color(0xFFF8F9FD);
const _border = Color(0xFFD8DDE9);

class BackupRestoreScreen extends ConsumerWidget {
  const BackupRestoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(backupProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : _page,
      appBar: AppBar(
        title: const Text(
          'Backup & Restore',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _BackupError(
          message: _errorMessage(error),
          onRetry: () => ref.invalidate(backupProvider),
        ),
        data: (state) => _BackupContent(state: state),
      ),
    );
  }
}

class _BackupContent extends ConsumerWidget {
  const _BackupContent({required this.state});
  final BackupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = state.latest;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        _SummaryCard(state: state),
        if (state.isBusy) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: state.progress),
          const SizedBox(height: 5),
          Text(
            '${_operationLabel(state.operation)} '
            '${(state.progress * 100).round()}%',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 9),
          ),
        ],
        if (state.message != null) ...[
          const SizedBox(height: 10),
          _MessageBanner(message: state.message!, error: false),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 10),
          _MessageBanner(message: state.error!, error: true),
        ],
        if (state.restoreResult != null) ...[
          const SizedBox(height: 10),
          _RestoreResultCard(result: state.restoreResult!),
        ],
        const SizedBox(height: 14),
        _SettingsCard(
          children: [
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.autorenew_rounded, color: _blue),
              title: const Text(
                'Automatic Backup',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Back up when the app opens and the schedule is due',
                style: TextStyle(fontSize: 8),
              ),
              value: state.automaticEnabled,
              onChanged: state.isBusy
                  ? null
                  : ref.read(backupProvider.notifier).setAutomatic,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.schedule_rounded, color: _blue),
              title: const Text(
                'Frequency',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
              trailing: DropdownButton<String>(
                value: state.frequency,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                ],
                onChanged: state.isBusy
                    ? null
                    : (value) {
                        if (value != null) {
                          ref.read(backupProvider.notifier).setFrequency(value);
                        }
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: state.isBusy
              ? null
              : ref.read(backupProvider.notifier).backupNow,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Backup Now'),
        ),
        const SizedBox(height: 9),
        OutlinedButton.icon(
          onPressed: state.isBusy || state.backups.isEmpty
              ? null
              : () => _restore(context, ref),
          icon: const Icon(Icons.restore_rounded),
          label: const Text('Restore Backup'),
        ),
        const SizedBox(height: 9),
        OutlinedButton.icon(
          onPressed: state.isBusy || latest == null
              ? null
              : () => ref.read(backupProvider.notifier).exportBackup(latest),
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Export Backup'),
        ),
        const SizedBox(height: 9),
        TextButton.icon(
          onPressed: state.isBusy || latest == null
              ? null
              : () => _delete(context, ref, latest),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete Backup'),
          style: TextButton.styleFrom(foregroundColor: _red),
        ),
      ],
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final metadata = await showModalBottomSheet<BackupMetadataModel>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BackupSelectionBottomSheet(backups: state.backups),
    );
    if (metadata == null || !context.mounted) return;
    final backup = await ref
        .read(backupProvider.notifier)
        .prepareRestore(metadata);
    if (backup == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          RestoreConfirmationDialog(metadata: metadata, backup: backup),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(backupProvider.notifier).restoreSelected();
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BackupMetadataModel metadata,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete backup?'),
        content: Text(
          'This permanently deletes the backup from '
          '${_date(metadata.createdAt)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(backupProvider.notifier).deleteBackup(metadata);
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});
  final BackupState state;

  @override
  Widget build(BuildContext context) {
    final latest = state.latest;
    return _SettingsCard(
      children: [
        _SummaryRow(
          icon: Icons.history_rounded,
          label: 'Last Backup',
          value: latest == null ? 'No backup created' : _date(latest.createdAt),
        ),
        _SummaryRow(
          icon: Icons.cloud_done_outlined,
          label: 'Backup Status',
          value: state.isBusy
              ? _operationLabel(state.operation)
              : latest?.status == 'completed'
              ? 'Completed'
              : 'Not backed up',
        ),
        _SummaryRow(
          icon: Icons.insert_drive_file_outlined,
          label: 'File Size',
          value: latest == null ? '0 B' : _fileSize(latest.fileSize),
        ),
        _SummaryRow(
          icon: Icons.storage_outlined,
          label: 'Record Count',
          value: '${latest?.recordCount ?? 0}',
          divider: false,
        ),
      ],
    );
  }
}

class BackupSelectionBottomSheet extends StatelessWidget {
  const BackupSelectionBottomSheet({required this.backups, super.key});
  final List<BackupMetadataModel> backups;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const ListTile(
        title: Text(
          'Select a Backup',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('Choose the version you want to restore.'),
      ),
      Flexible(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: backups.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final backup = backups[index];
            return ListTile(
              leading: const Icon(Icons.cloud_done_outlined, color: _blue),
              title: Text(_date(backup.createdAt)),
              subtitle: Text(
                '${_fileSize(backup.fileSize)} • '
                '${backup.recordCount} records • Schema ${backup.schemaVersion}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(context, backup),
            );
          },
        ),
      ),
    ],
  );
}

class RestoreConfirmationDialog extends StatelessWidget {
  const RestoreConfirmationDialog({
    required this.metadata,
    required this.backup,
    super.key,
  });
  final BackupMetadataModel metadata;
  final BackupModel backup;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.warning_amber_rounded, color: _red, size: 38),
    title: const Text('Restore this backup?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Created: ${_date(metadata.createdAt)}'),
        Text('File size: ${_fileSize(metadata.fileSize)}'),
        Text('Records: ${backup.recordCount}'),
        Text('Schema version: ${backup.schemaVersion}'),
        const SizedBox(height: 14),
        const Text(
          'Warning: matching document IDs will be updated with backup data. '
          'Current records that are not in this backup will remain unchanged.',
          style: TextStyle(color: _red, fontWeight: FontWeight.w700),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: _red),
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Restore Data'),
      ),
    ],
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.divider = true,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool divider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        dense: true,
        leading: Icon(icon, color: _blue, size: 19),
        title: Text(label, style: const TextStyle(fontSize: 9)),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
        ),
      ),
      if (divider) const Divider(height: 1, indent: 48),
    ],
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
    ),
    child: Column(children: children),
  );
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.error});
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: (error ? _red : _green).withValues(alpha: .09),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      children: [
        Icon(
          error ? Icons.error_outline_rounded : Icons.check_circle_outline,
          color: error ? _red : _green,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 9))),
      ],
    ),
  );
}

class _RestoreResultCard extends StatelessWidget {
  const _RestoreResultCard({required this.result});
  final RestoreResult result;

  @override
  Widget build(BuildContext context) => _SettingsCard(
    children: [
      _SummaryRow(
        icon: Icons.check_circle_outline,
        label: 'Successfully Restored',
        value: '${result.restored}',
      ),
      _SummaryRow(
        icon: Icons.error_outline_rounded,
        label: 'Failed Records',
        value: '${result.failed}',
        divider: false,
      ),
    ],
  );
}

class _BackupError extends StatelessWidget {
  const _BackupError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, color: _red, size: 48),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

String _date(DateTime value) =>
    DateFormat('dd MMM yyyy, hh:mm a').format(value);

String _fileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _operationLabel(BackupOperation operation) => switch (operation) {
  BackupOperation.idle => 'Ready',
  BackupOperation.backingUp => 'Uploading backup',
  BackupOperation.downloading => 'Downloading backup',
  BackupOperation.restoring => 'Restoring records',
  BackupOperation.exporting => 'Exporting backup',
  BackupOperation.deleting => 'Deleting backup',
};

String _errorMessage(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('permission')) return 'Backup access was denied.';
  return 'Could not load backups.';
}
