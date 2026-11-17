import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes/app_routes.dart';
import '../../providers/app_providers.dart';
import '../../providers/language_providers.dart';
import '../../providers/startup_providers.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  Future<void> _continue() async {
    if (ref.read(languageProvider).isLoading) return;
    final saved = await ref.read(languageProvider.notifier).save();
    if (!mounted) return;
    if (saved) {
      ref.invalidate(startupProvider);
      final user = ref.read(currentUserProvider);
      final ownerId = user?.uid ?? 'local_user';
      try {
        final business = await ref
            .read(businessRepositoryProvider)
            .watchForOwner(ownerId)
            .first
            .timeout(const Duration(seconds: 5));
        if (!mounted) return;
        context.go(business == null ? AppRoutes.businessSetup : AppRoutes.main);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not continue: $error')));
      }
      return;
    }
    final error = ref.read(languageProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'Could not save your language. Please try again.'
              : 'Could not save your language: $error',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final selected = language.value ?? 'en';
    final saving = language.isLoading;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 34, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 58,
                maxWidth: 520,
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.asset(
                      'assets/images/language_globe.png',
                      width: 150,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Choose Your Language',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF07172E),
                      fontSize: 22,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Select your preferred language to manage your\n'
                    'business ledgers with ease.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF4E596D),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 27),
                  _LanguageTile(
                    selected: selected == 'en',
                    icon: Icons.language_rounded,
                    title: 'English',
                    subtitle: 'System Default',
                    onTap: saving
                        ? null
                        : () =>
                              ref.read(languageProvider.notifier).select('en'),
                  ),
                  const SizedBox(height: 12),
                  _LanguageTile(
                    selected: selected == 'ur',
                    icon: Icons.translate_rounded,
                    title: 'اردو',
                    subtitle: 'Urdu',
                    onTap: saving
                        ? null
                        : () =>
                              ref.read(languageProvider.notifier).select('ur'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0733A2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 3,
                        shadowColor: const Color(0x420733A2),
                      ),
                      onPressed: saving ? null : _continue,
                      child: saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 9),
                                Icon(Icons.arrow_forward_rounded, size: 21),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'You can change this anytime in settings.',
                    style: TextStyle(color: Color(0xFF536078), fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFF2F5FF) : Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: BorderSide(
        color: selected ? const Color(0xFF1749CD) : const Color(0xFFD4D9E5),
        width: selected ? 1.2 : 1,
      ),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4EBFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF0733A2), size: 21),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF08162B),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF4E596D),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF052E9B),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
