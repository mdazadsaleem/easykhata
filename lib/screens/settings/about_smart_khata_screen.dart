import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes/app_routes.dart';
import '../../providers/support_providers.dart';

const _blue = Color(0xFF173EB5);
const _muted = Color(0xFF667085);
const _border = Color(0xFFDDE1EB);
const _page = Color(0xFFF8F9FD);

class AboutSmartKhataScreen extends ConsumerWidget {
  const AboutSmartKhataScreen({super.key});

  static const _developerName = String.fromEnvironment(
    'DEVELOPER_NAME',
    defaultValue: 'Smart Khata Team',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? colors.surface
          : _page,
      appBar: AppBar(
        title: const Text(
          'About Smart Khata',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 24, 14, 28),
        children: [
          Center(
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _blue.withValues(alpha: .22),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Smart Khata',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          version.when(
            loading: () => const Center(
              child: SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, _) => const Text(
              'Version unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 9),
            ),
            data: (value) => Text(
              'Version $value',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 9),
            ),
          ),
          const SizedBox(height: 22),
          _AboutCard(
            child: Text(
              'Smart Khata is a secure digital ledger and bookkeeping '
              'application designed to help small businesses manage customer '
              'balances, cashbook activity, payment reminders, reports, and '
              'business backups from one place.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 10,
                height: 1.65,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _AboutCard(
            child: Column(
              children: [
                _AboutTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () => context.push(AppRoutes.privacyPolicy),
                ),
                const Divider(height: 1),
                _AboutTile(
                  icon: Icons.gavel_outlined,
                  title: 'Terms and Conditions',
                  onTap: () => context.push(AppRoutes.termsConditions),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AboutCard(
            child: Column(
              children: [
                const Icon(Icons.code_rounded, color: _blue, size: 25),
                const SizedBox(height: 8),
                Text(
                  'Developed by',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 9),
                ),
                const SizedBox(height: 3),
                Text(
                  _developerName,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '© ${DateTime.now().year} Smart Khata. All rights reserved.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.outlineVariant
            : _border,
      ),
    ),
    child: child,
  );
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: _blue, size: 19),
    title: Text(
      title,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
    onTap: onTap,
  );
}
