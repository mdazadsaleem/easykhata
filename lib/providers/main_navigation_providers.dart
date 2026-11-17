import 'package:flutter_riverpod/flutter_riverpod.dart';

final mainNavigationIndexProvider =
    NotifierProvider<MainNavigationIndexNotifier, int>(
      MainNavigationIndexNotifier.new,
    );

class MainNavigationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) {
    if (index < 0 || index > 4 || index == state) return;
    state = index;
  }

  void goHome() => state = 0;
}
