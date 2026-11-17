import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/main_navigation_providers.dart';
import '../cashbook/cashbook_screen.dart';
import '../customers/customers_screen.dart';
import '../home/home_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

const _navBlue = Color(0xFF173EB5);

class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  static const _screens = [
    HomeScreen(),
    CustomersScreen(),
    CashbookScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(mainNavigationIndexProvider);
    final navigation = ref.read(mainNavigationIndexProvider.notifier);
    const selectedIcons = [
      Icons.home_rounded,
      Icons.people_rounded,
      Icons.menu_book_rounded,
      Icons.bar_chart_rounded,
      Icons.settings_rounded,
    ];

    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectedIndex != 0) navigation.goHome();
      },
      child: Scaffold(
        extendBody: false,
        body: IndexedStack(index: selectedIndex, children: _screens),
        bottomNavigationBar: _CurvedNavigationBar(
          selectedIndex: selectedIndex,
          selectedIcons: selectedIcons,
          onSelected: navigation.select,
        ),
      ),
    );
  }
}

class _CurvedNavigationBar extends StatelessWidget {
  const _CurvedNavigationBar({
    required this.selectedIndex,
    required this.selectedIcons,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<IconData> selectedIcons;
  final ValueChanged<int> onSelected;

  static const _icons = [
    Icons.home_outlined,
    Icons.people_outline_rounded,
    Icons.menu_book_outlined,
    Icons.bar_chart_outlined,
    Icons.settings_outlined,
  ];
  static const _labels = [
    'Home',
    'Customers',
    'Cashbook',
    'Reports',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    const barColor = _navBlue;
    const inactiveColor = Color(0xCCFFFFFF);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selectedIndex.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      builder: (context, position, _) => LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / _icons.length;
          final center = (position + .5) * itemWidth;
          return SizedBox(
            height: 68 + bottomInset,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CurvedBarPainter(center: center, color: barColor),
                  ),
                ),
                Positioned.fill(
                  top: 19,
                  bottom: bottomInset,
                  child: Row(
                    children: List.generate(
                      _icons.length,
                      (index) => Expanded(
                        child: Semantics(
                          button: true,
                          selected: index == selectedIndex,
                          label: _labels[index],
                          child: InkResponse(
                            onTap: () => onSelected(index),
                            radius: 28,
                            child: Center(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: index == selectedIndex ? 0 : 1,
                                child: Icon(
                                  _icons[index],
                                  color: inactiveColor,
                                  size: 23,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: center - 27,
                  top: 0,
                  width: 54,
                  height: 54,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: barColor,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x40102870),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Icon(
                                selectedIcons[selectedIndex],
                                key: ValueKey(selectedIndex),
                                color: _navBlue,
                                size: 23,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CurvedBarPainter extends CustomPainter {
  const _CurvedBarPainter({required this.center, required this.color});

  final double center;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 18)
      ..lineTo(center - 44, 18)
      ..cubicTo(center - 34, 18, center - 32, 5, center - 20, 5)
      ..cubicTo(center - 10, 5, center - 11, 0, center, 0)
      ..cubicTo(center + 11, 0, center + 10, 5, center + 20, 5)
      ..cubicTo(center + 32, 5, center + 34, 18, center + 44, 18)
      ..lineTo(size.width, 18)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black.withValues(alpha: .12), 5, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CurvedBarPainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.color != color;
}
