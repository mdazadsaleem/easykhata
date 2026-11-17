import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_khata/screens/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('onboarding uses Smart Khata content', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Manage Your Accounts'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
