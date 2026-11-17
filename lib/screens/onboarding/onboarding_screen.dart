import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes/app_routes.dart';
import '../../providers/onboarding_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _navigating = false;

  static const _pages = [
    (
      'Manage Your Accounts',
      'Keep customer and supplier accounts in one secure place.',
      Icons.people_alt_outlined,
    ),
    (
      'Track Every Payment',
      'Record money given and money received instantly.',
      Icons.payments_outlined,
    ),
    (
      'Grow Your Business',
      'Understand your cash flow with simple reports.',
      Icons.trending_up_rounded,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    final completed = await ref.read(onboardingProvider.notifier).complete();
    if (!mounted) return;
    if (completed) {
      context.go(AppRoutes.language);
      return;
    }
    setState(() => _navigating = false);
    final error = ref.read(onboardingProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'Could not save onboarding progress. Please try again.'
              : 'Could not save onboarding progress: $error',
        ),
      ),
    );
  }

  Future<void> _next() async {
    if (_page == _pages.length - 1) {
      await _complete();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = ref.watch(onboardingProvider);
    final submitting = _navigating || onboarding.isLoading;

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: submitting ? null : _complete,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                physics: submitting
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) {
                  final item = _pages[index];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final iconSize = (constraints.maxWidth * 0.3).clamp(
                        88.0,
                        130.0,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 20,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.$3,
                              size: iconSize,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 32),
                            Text(
                              item.$1,
                              style: Theme.of(context).textTheme.headlineMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item.$2,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  width: index == _page ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index == _page
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: submitting ? null : _next,
                  child: submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _page == _pages.length - 1 ? 'Get Started' : 'Next',
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
