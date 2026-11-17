import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/customer_model.dart';
import '../../screens/authentication/otp_verification_screen.dart';
import '../../screens/authentication/phone_login_screen.dart';
import '../../screens/app_lock/app_lock_screen.dart';
import '../../screens/business_setup/business_setup_screen.dart';
import '../../screens/business_setup/business_details_screen.dart';
import '../../screens/common/feature_screen.dart';
import '../../screens/customers/add_customer_screen.dart';
import '../../screens/customers/customer_details_screen.dart';
import '../../screens/customers/customers_screen.dart';
import '../../screens/cashbook/add_cash_entry_screen.dart';
import '../../screens/cashbook/edit_cash_entry_screen.dart';
import '../../screens/customers/edit_customer_screen.dart';
import '../../screens/transactions/add_transaction_screen.dart';
import '../../screens/transactions/edit_transaction_screen.dart';
import '../../screens/main/main_navigation_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/onboarding/language_selection_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/profile/user_profile_screen.dart';
import '../../screens/reminders/payment_reminders_screen.dart';
import '../../screens/reports/customer_statement_preview_screen.dart';
import '../../screens/search/global_search_screen.dart';
import '../../screens/settings/theme_settings_screen.dart';
import '../../screens/settings/support_content_screen.dart';
import '../../screens/settings/help_support_screen.dart';
import '../../screens/settings/about_smart_khata_screen.dart';
import '../../screens/settings/backup_restore_screen.dart';
import '../../screens/splash/splash_screen.dart';
import 'app_routes.dart';
import 'otp_route_args.dart';

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.language,
        builder: (_, _) => const LanguageSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (_, s) {
          return OtpVerificationScreen(arguments: s.extra! as OtpRouteArgs);
        },
      ),
      GoRoute(
        path: AppRoutes.businessSetup,
        builder: (_, _) => const BusinessSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.businessDetails,
        builder: (_, _) => const BusinessDetailsScreen(),
      ),
      GoRoute(
        path: AppRoutes.main,
        builder: (_, _) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: AppRoutes.customers,
        builder: (_, _) => const CustomersScreen(),
      ),
      GoRoute(
        path: AppRoutes.addCustomer,
        builder: (_, _) => const AddCustomerScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.customerDetails}/:customerId',
        builder: (_, s) =>
            CustomerDetailsScreen(customerId: s.pathParameters['customerId']!),
      ),
      GoRoute(
        path: '${AppRoutes.editCustomer}/:customerId',
        builder: (_, state) =>
            EditCustomerScreen(customerId: state.pathParameters['customerId']!),
      ),
      GoRoute(
        path: AppRoutes.themeSettings,
        builder: (_, _) => const ThemeSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.backupRestore,
        builder: (_, _) => const BackupRestoreScreen(),
      ),
      GoRoute(
        path: AppRoutes.addTransaction,
        builder: (_, state) {
          final extra = state.extra;
          final queryCustomerId = state.uri.queryParameters['customerId'];
          final queryType = state.uri.queryParameters['type'];
          if (extra is Map<String, dynamic>) {
            final legacyCustomer = extra['customer'] as CustomerModel?;
            return AddTransactionScreen(
              customerId:
                  queryCustomerId ??
                  extra['customerId'] as String? ??
                  legacyCustomer?.id,
              initialType: queryType ?? extra['type'] as String? ?? 'gave',
            );
          }
          return AddTransactionScreen(
            customerId: queryCustomerId,
            initialType: queryType ?? 'gave',
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.editTransaction}/:transactionId',
        builder: (_, state) => EditTransactionScreen(
          transactionId: state.pathParameters['transactionId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.reminders,
        builder: (_, _) => const PaymentRemindersScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (_, _) => const GlobalSearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, _) => const UserProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.statementPreview,
        builder: (_, state) {
          final customerId = state.uri.queryParameters['customerId'] ?? '';
          final startDate = DateTime.tryParse(
            state.uri.queryParameters['startDate'] ?? '',
          );
          final endDate = DateTime.tryParse(
            state.uri.queryParameters['endDate'] ?? '',
          );
          final now = DateTime.now();
          return CustomerStatementPreviewScreen(
            customerId: customerId,
            startDate: startDate ?? DateTime(now.year, now.month, 1),
            endDate: endDate ?? now,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.addCashEntry,
        builder: (_, state) {
          final extraType = state.extra as String?;
          return AddCashEntryScreen(
            initialType:
                state.uri.queryParameters['type'] ?? extraType ?? 'cashIn',
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.editCashEntry}/:entryId',
        builder: (_, state) =>
            EditCashEntryScreen(entryId: state.pathParameters['entryId']!),
      ),
      GoRoute(
        path: AppRoutes.appLock,
        builder: (_, _) => const AppLockScreen(),
      ),
      GoRoute(
        path: AppRoutes.helpSupport,
        builder: (_, _) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: AppRoutes.faqs,
        builder: (_, _) =>
            const SupportContentScreen(type: SupportContentType.faqs),
      ),
      GoRoute(
        path: AppRoutes.contactSupport,
        builder: (_, _) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        builder: (_, _) =>
            const SupportContentScreen(type: SupportContentType.privacy),
      ),
      GoRoute(
        path: AppRoutes.termsConditions,
        builder: (_, _) =>
            const SupportContentScreen(type: SupportContentType.terms),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (_, _) => const AboutSmartKhataScreen(),
      ),
      for (final route in <String, String>{
        AppRoutes.addReminder: 'Add Reminder',
      }.entries)
        GoRoute(path: route.key, builder: (_, _) => FeatureScreen(route.value)),
    ],
  ),
);
