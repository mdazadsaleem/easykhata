import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/support_providers.dart';

const _blue = Color(0xFF173EB5);
const _green = Color(0xFF009E60);
const _red = Color(0xFFD92D3A);
const _muted = Color(0xFF667085);
const _border = Color(0xFFDDE1EB);
const _page = Color(0xFFF8F9FD);

class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    (
      'How are customer balances calculated?',
      'Balances update whenever a ledger transaction is added, edited, or deleted.',
    ),
    (
      'How can I back up my business data?',
      'Open Settings, then Backup & Restore to create, export, restore, or delete a local backup.',
    ),
    (
      'Can I use Smart Khata without internet?',
      'Previously loaded data may remain available temporarily, but synchronization and backups require internet access.',
    ),
    (
      'How do I secure the application?',
      'Open App Lock to create a PIN, enable biometrics, and choose an automatic lock timer.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value ?? 'Loading';
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : _page,
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          const _SectionLabel('FREQUENTLY ASKED QUESTIONS'),
          _SupportCard(
            children: _faqs
                .map(
                  (faq) => ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    title: Text(
                      faq.$1,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          faq.$2,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 9,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          const _SectionLabel('CONTACT SUPPORT'),
          _SupportCard(
            children: [
              _SupportTile(
                icon: Icons.support_agent_rounded,
                title: 'Contact Support',
                subtitle: 'Open your email application',
                onTap: () => _email(context, ref),
              ),
              _SupportTile(
                icon: Icons.chat_outlined,
                title: 'WhatsApp Support',
                subtitle: 'Open WhatsApp with support information',
                onTap: () => _whatsApp(context, ref),
              ),
              _SupportTile(
                icon: Icons.email_outlined,
                title: 'Email Support',
                subtitle: 'support@smartkhata.app',
                onTap: () => _email(context, ref),
                divider: false,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _SectionLabel('REQUESTS & FEEDBACK'),
          _SupportCard(
            children: [
              _SupportTile(
                icon: Icons.bug_report_outlined,
                title: 'Report a Problem',
                subtitle: 'Send details and an optional screenshot',
                onTap: () => _openForm(context, 'Technical Issue'),
              ),
              _SupportTile(
                icon: Icons.rate_review_outlined,
                title: 'Send Feedback',
                subtitle: 'Share an idea or suggestion',
                onTap: () => _openForm(context, 'Feedback'),
                divider: false,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SupportCard(
            children: [
              _SupportTile(
                icon: Icons.info_outline_rounded,
                title: 'App Version',
                subtitle: version,
                divider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _whatsApp(BuildContext context, WidgetRef ref) async {
    final opened = await ref.read(supportLauncherProvider).openWhatsApp();
    if (!opened && context.mounted) {
      _message(context, 'WhatsApp could not be opened.');
    }
  }

  Future<void> _email(BuildContext context, WidgetRef ref) async {
    final opened = await ref.read(supportLauncherProvider).openEmail();
    if (!opened && context.mounted) {
      _message(context, 'No email application is available.');
    }
  }

  Future<void> _openForm(BuildContext context, String category) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportRequestForm(initialCategory: category),
      ),
    );
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class SupportRequestForm extends ConsumerStatefulWidget {
  const SupportRequestForm({required this.initialCategory, super.key});
  final String initialCategory;

  @override
  ConsumerState<SupportRequestForm> createState() => _SupportRequestFormState();
}

class _SupportRequestFormState extends ConsumerState<SupportRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  static const _categories = [
    'Technical Issue',
    'Account',
    'Backup & Restore',
    'Data or Balance',
    'Feedback',
    'Other',
  ];

  late String _category;
  File? _screenshot;

  @override
  void initState() {
    super.initState();
    _category = _categories.contains(widget.initialCategory)
        ? widget.initialCategory
        : _categories.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supportSubmissionProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(supportSubmissionProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : _page,
      appBar: AppBar(
        title: Text(
          widget.initialCategory == 'Feedback'
              ? 'Send Feedback'
              : 'Report a Problem',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: submission.success
          ? _SuccessState(requestId: submission.requestId ?? '')
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
                children: [
                  _SupportCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _subjectController,
                              enabled: !submission.submitting,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Subject',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().length < 3
                                  ? 'Enter a clear subject.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _category,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                              ),
                              items: _categories
                                  .map(
                                    (category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category),
                                    ),
                                  )
                                  .toList(),
                              onChanged: submission.submitting
                                  ? null
                                  : (value) =>
                                        setState(() => _category = value!),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descriptionController,
                              enabled: !submission.submitting,
                              minLines: 5,
                              maxLines: 8,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                alignLabelWithHint: true,
                              ),
                              validator: (value) =>
                                  value == null || value.trim().length < 10
                                  ? 'Describe the issue in at least 10 characters.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            if (_screenshot != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _screenshot!,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            OutlinedButton.icon(
                              onPressed: submission.submitting
                                  ? null
                                  : _pickScreenshot,
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                              label: Text(
                                _screenshot == null
                                    ? 'Add Optional Screenshot'
                                    : 'Replace Screenshot',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (submission.submitting) ...[
                    const SizedBox(height: 14),
                    LinearProgressIndicator(value: submission.progress),
                    const SizedBox(height: 5),
                    Text(
                      'Submitting ${(submission.progress * 100).round()}%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted, fontSize: 9),
                    ),
                  ],
                  if (submission.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      submission.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _red, fontSize: 9),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: submission.submitting ? null : _submit,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Submit Request'),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _pickScreenshot() async {
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1440,
    );
    if (selected == null || !mounted) return;
    final length = await selected.length();
    if (!mounted) return;
    if (length > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screenshot must be smaller than 5 MB.')),
      );
      return;
    }
    setState(() => _screenshot = File(selected.path));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;
    await ref
        .read(supportSubmissionProvider.notifier)
        .submit(
          subject: _subjectController.text,
          category: _category,
          description: _descriptionController.text,
          screenshot: _screenshot,
        );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: _green, size: 64),
          const SizedBox(height: 14),
          const Text(
            'Request Submitted',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            'Reference: $requestId\nThe support team can now review your request.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 10, height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 6),
    child: Text(
      label,
      style: const TextStyle(
        color: _blue,
        fontSize: 8,
        fontWeight: FontWeight.w800,
        letterSpacing: .5,
      ),
    ),
  );
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.children});
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

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.divider = true,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        dense: true,
        onTap: onTap,
        leading: Icon(icon, color: _blue, size: 19),
        title: Text(
          title,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: _muted, fontSize: 8),
        ),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right_rounded, size: 18),
      ),
      if (divider) const Divider(height: 1, indent: 48),
    ],
  );
}
