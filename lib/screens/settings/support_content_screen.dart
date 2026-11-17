import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum SupportContentType { help, faqs, contact, privacy, terms, about }

class SupportContentScreen extends StatelessWidget {
  const SupportContentScreen({required this.type, super.key});
  final SupportContentType type;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title)),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Icon(_icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          _title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        if (type == SupportContentType.faqs)
          ..._faqs.map(
            (item) => ExpansionTile(
              title: Text(item.$1),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Align(alignment: Alignment.centerLeft, child: Text(item.$2)),
              ],
            ),
          )
        else
          Text(_content, style: const TextStyle(height: 1.6)),
        if (type == SupportContentType.help ||
            type == SupportContentType.contact) ...[
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => _contact(context),
            icon: const Icon(Icons.email_outlined),
            label: const Text('Email Support'),
          ),
        ],
      ],
    ),
  );

  Future<void> _contact(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@smartkhata.app',
      queryParameters: {'subject': 'Smart Khata Support'},
    );
    if (!await launchUrl(uri) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email application is available.')),
      );
    }
  }

  String get _title => switch (type) {
    SupportContentType.help => 'Help & Support',
    SupportContentType.faqs => 'Frequently Asked Questions',
    SupportContentType.contact => 'Contact Support',
    SupportContentType.privacy => 'Privacy Policy',
    SupportContentType.terms => 'Terms & Conditions',
    SupportContentType.about => 'About Smart Khata',
  };

  IconData get _icon => switch (type) {
    SupportContentType.help => Icons.help_outline_rounded,
    SupportContentType.faqs => Icons.quiz_outlined,
    SupportContentType.contact => Icons.support_agent_rounded,
    SupportContentType.privacy => Icons.privacy_tip_outlined,
    SupportContentType.terms => Icons.gavel_outlined,
    SupportContentType.about => Icons.info_outline_rounded,
  };

  String get _content => switch (type) {
    SupportContentType.help =>
      'Smart Khata keeps customer ledgers, cashbook entries, reminders and '
          'reports together. Use the Customers tab for account balances, the '
          'Cashbook tab for cash movement, and Reports for business summaries.',
    SupportContentType.contact =>
      'For account, billing, data or technical assistance, contact the Smart '
          'Khata support team. Include a short description of the issue and avoid '
          'sharing passwords, PINs or verification codes.',
    SupportContentType.privacy =>
      'Smart Khata stores the account and business information required to '
          'provide ledger, reporting, backup and notification features. Access is '
          'restricted to the authenticated account. You can export your business '
          'data or request account deletion from Settings.',
    SupportContentType.terms =>
      'Use Smart Khata only for lawful bookkeeping activities. You remain '
          'responsible for the accuracy of entered records, maintaining access to '
          'your account, and keeping independent backups of important data.',
    SupportContentType.about =>
      'Smart Khata is a secure digital ledger and bookkeeping application '
          'designed for small businesses. Version 1.0.0.',
    SupportContentType.faqs => '',
  };

  static const _faqs = [
    (
      'How are balances calculated?',
      'Balances update whenever a ledger transaction is added, edited or deleted.',
    ),
    (
      'Can I export my business data?',
      'Yes. Use Export Business Data in Settings to create and share a JSON backup.',
    ),
    (
      'How do I protect the app?',
      'Open App Lock to create a PIN and enable supported biometric options.',
    ),
    (
      'Why can’t I change my phone directly?',
      'Phone verification is required before changing a phone number.',
    ),
  ];
}
