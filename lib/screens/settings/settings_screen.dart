import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes/app_routes.dart';
import '../../providers/business_providers.dart';
import '../../providers/business_data_export_provider.dart';
import '../../providers/app_lock_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/language_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/settings_preferences_provider.dart';

const _blue = Color(0xFF173EB5);
const _green = Color(0xFF009E60);
const _muted = Color(0xFF667085);
const _border = Color(0xFFDDE1EB);
const _page = Color(0xFFF8F9FD);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _changePhone() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change phone number?'),
        content: const Text(
          'Your identity must be verified again. You will be signed out and '
          'taken to phone verification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _exportData() async {
    final success = await ref
        .read(businessDataExportProvider.notifier)
        .export();
    if (!mounted || success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not export business data.')),
    );
  }

  Future<void> _selectDateFormat(String current) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Date Format',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final format in const [
              'dd MMM yyyy',
              'dd/MM/yyyy',
              'MM/dd/yyyy',
              'yyyy-MM-dd',
            ])
              ListTile(
                title: Text(format),
                trailing: format == current
                    ? const Icon(Icons.check_circle_rounded, color: _blue)
                    : null,
                onTap: () => Navigator.pop(sheetContext, format),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    final success = await ref
        .read(settingsPreferencesProvider.notifier)
        .setDateFormat(selected);
    if (!mounted || success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not save date format.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final business = ref.watch(currentBusinessProvider).value;
    final language = ref.watch(languageProvider).value ?? 'en';
    final themeMode = ref.watch(themeModeProvider);
    final preferences =
        ref.watch(settingsPreferencesProvider).value ??
        const SettingsPreferences();
    final lock = ref.watch(appLockSettingsProvider).value;
    final exporting = ref.watch(businessDataExportProvider).isLoading;
    final displayName =
        user?.displayName ?? business?.ownerName ?? 'Smart Khata User';
    final contact = user?.email ?? user?.phoneNumber ?? 'Account connected';

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : _page,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(13, 9, 13, 28),
          children: [
            _TopBar(
              businessName: business?.businessName ?? 'Smart Khata',
              onNotifications: () => context.push(AppRoutes.notifications),
            ),
            const SizedBox(height: 13),
            _ProfileCard(
              name: displayName,
              contact: contact,
              photoUrl: user?.photoURL,
              onTap: () => context.push(AppRoutes.profile),
            ),
            const SizedBox(height: 14),
            const _SectionLabel('ACCOUNT'),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile',
                  onTap: () => context.push(AppRoutes.profile),
                ),
                _SettingsRow(
                  icon: Icons.business_outlined,
                  title: 'Business Details',
                  onTap: () => context.push(AppRoutes.businessDetails),
                ),
                _SettingsRow(
                  icon: Icons.phone_android_outlined,
                  title: 'Change Phone Number',
                  onTap: _changePhone,
                  divider: false,
                ),
              ],
            ),
            const SizedBox(height: 13),
            const _SectionLabel('PREFERENCES'),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.language_rounded,
                  title: 'Language',
                  subtitle: language == 'ur' ? 'Urdu' : 'English (US)',
                  onTap: () => context.push(AppRoutes.language),
                ),
                _SettingsRow(
                  icon: Icons.payments_outlined,
                  title: 'Currency',
                  subtitle: business?.currency ?? 'PKR',
                  onTap: () => context.push(AppRoutes.businessDetails),
                ),
                _SettingsRow(
                  icon: Icons.dark_mode_outlined,
                  title: 'Theme',
                  trailing: _ThemePreview(mode: themeMode),
                  onTap: () => context.push(AppRoutes.themeSettings),
                ),
                _SettingsRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  trailing: Switch.adaptive(
                    value: preferences.notificationsEnabled,
                    activeTrackColor: _blue,
                    onChanged: preferences.isSaving
                        ? null
                        : ref
                              .read(settingsPreferencesProvider.notifier)
                              .setNotifications,
                  ),
                ),
                _SettingsRow(
                  icon: Icons.date_range_outlined,
                  title: 'Date Format',
                  subtitle: preferences.dateFormat,
                  onTap: () => _selectDateFormat(preferences.dateFormat),
                  divider: false,
                ),
              ],
            ),
            const SizedBox(height: 13),
            const _SectionLabel('DATA & SECURITY'),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.cloud_sync_outlined,
                  title: 'Backup & Restore',
                  onTap: () => context.push(AppRoutes.backupRestore),
                ),
                _SettingsRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'App Lock',
                  trailing: _StatusBadge(
                    lock?.hasPin == true ? 'Enabled' : 'Not set',
                    neutral: lock?.hasPin != true,
                  ),
                  onTap: () => context.push(AppRoutes.appLock),
                ),
                _SettingsRow(
                  icon: Icons.file_download_outlined,
                  title: 'Export Business Data',
                  trailing: exporting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const _StatusBadge('JSON', neutral: true),
                  onTap: exporting ? null : _exportData,
                ),
                _SettingsRow(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric Lock',
                  subtitle: lock?.fingerprint == true ? 'Enabled' : 'Disabled',
                  onTap: () => context.push(AppRoutes.appLock),
                  divider: false,
                ),
              ],
            ),
            const SizedBox(height: 13),
            const _SectionLabel('SUPPORT'),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.headset_mic_outlined,
                  title: 'Help & Support',
                  onTap: () => context.push(AppRoutes.helpSupport),
                ),
                _SettingsRow(
                  icon: Icons.flag_outlined,
                  title: 'FAQ',
                  onTap: () => context.push(AppRoutes.faqs),
                ),
                _SettingsRow(
                  icon: Icons.support_agent_rounded,
                  title: 'Contact Support',
                  onTap: () => context.push(AppRoutes.contactSupport),
                ),
                _SettingsRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () => context.push(AppRoutes.privacyPolicy),
                ),
                _SettingsRow(
                  icon: Icons.gavel_outlined,
                  title: 'Terms & Conditions',
                  onTap: () => context.push(AppRoutes.termsConditions),
                ),
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About Smart Khata',
                  onTap: () => context.push(AppRoutes.about),
                  divider: false,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'SMART KHATA PREMIUM • SECURE & SIMPLE\nMade with care for businesses',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 7,
                height: 1.6,
                letterSpacing: .3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.businessName, required this.onNotifications});
  final String businessName;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 31,
        height: 31,
        decoration: BoxDecoration(
          color: _blue,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.account_balance_wallet_rounded,
          color: Colors.white,
          size: 17,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          businessName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _blue,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onNotifications,
        icon: const Icon(
          Icons.notifications_none_rounded,
          color: _blue,
          size: 19,
        ),
      ),
    ],
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.contact,
    required this.photoUrl,
    required this.onTap,
  });
  final String name;
  final String contact;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: _border),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: _blue,
              backgroundImage: photoUrl == null || photoUrl!.isEmpty
                  ? null
                  : NetworkImage(photoUrl!),
              child: photoUrl == null || photoUrl!.isEmpty
                  ? Text(
                      _initials(name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    contact,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 8),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
          ],
        ),
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

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.divider = true,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -3),
        minLeadingWidth: 24,
        onTap: onTap,
        leading: Icon(icon, color: _blue, size: 16),
        title: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(color: _muted, fontSize: 7),
              ),
        trailing:
            trailing ??
            (onTap == null
                ? null
                : const Icon(
                    Icons.chevron_right_rounded,
                    color: _muted,
                    size: 17,
                  )),
      ),
      if (divider)
        const Divider(height: 1, indent: 42, color: Color(0xFFE8EBF2)),
    ],
  );
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.mode});
  final ThemeMode mode;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF1F7),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ThemeIcon(
          icon: Icons.light_mode_outlined,
          selected: mode == ThemeMode.light,
        ),
        _ThemeIcon(
          icon: Icons.dark_mode_outlined,
          selected: mode == ThemeMode.dark,
        ),
        _ThemeIcon(
          icon: Icons.settings_brightness_outlined,
          selected: mode == ThemeMode.system,
        ),
      ],
    ),
  );
}

class _ThemeIcon extends StatelessWidget {
  const _ThemeIcon({required this.icon, required this.selected});
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 25,
    height: 22,
    decoration: BoxDecoration(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      boxShadow: selected
          ? const [BoxShadow(color: Color(0x16000000), blurRadius: 3)]
          : null,
    ),
    child: Icon(icon, size: 13, color: selected ? _blue : _muted),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label, {this.neutral = false});
  final String label;
  final bool neutral;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: neutral ? const Color(0xFFF1F3F7) : const Color(0xFFE9F8F0),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: neutral ? _muted : _green,
        fontSize: 7,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return 'SK';
  return words.take(2).map((word) => word[0]).join().toUpperCase();
}
