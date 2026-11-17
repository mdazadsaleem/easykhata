# Easy Khata (Smart Khata) Project Explanation

## 1. Project Overview

Smart Khata is a Flutter bookkeeping application for small businesses. It helps
a business owner manage customers and suppliers, record money given and
received, maintain a cashbook, view reports, create payment reminders, generate
customer statements, back up data, and protect the app with a PIN or biometric
lock.

The app supports Android, iOS, web, Windows, Linux, and macOS through Flutter.

## 2. Main Technologies

| Technology | Purpose |
| --- | --- |
| Flutter/Dart | Cross-platform user interface and application logic |
| Riverpod | State management and dependency injection |
| GoRouter | Named navigation and route parameters |
| Hive / Hive Flutter | Local NoSQL database for businesses, customers, transactions, cashbook, reminders |
| Local File Storage | Business logos, receipts, and JSON backups stored in application documents directory |
| SharedPreferences | Onboarding, theme, language, and other local preferences |
| Flutter Secure Storage | Secure app-lock information |
| Local Auth | Fingerprint or device biometric authentication |
| Local Notifications | Scheduled reminders on the device |
| fl_chart | Report charts |
| pdf/printing/share_plus | Customer PDF statements, previewing, printing, and sharing |

The application runs 100% offline without any external cloud or login requirements.

## 3. Project Architecture

The project follows a layered structure:

```text
Screen/Widget
    |
    v
Riverpod Provider/Notifier
    |
    v
Repository or Service
    |
    v
Hive boxes, local storage, or device API
```

- `lib/screens/`: Pages and page-specific UI widgets.
- `lib/providers/`: Riverpod state, business logic, filters, and actions.
- `lib/repositories/`: Local CRUD operations and Hive database queries.
- `lib/models/`: Typed Dart models with local map conversion.
- `lib/core/services/`: PDF, export, notification, preference, and support services.
- `lib/core/security/`: Lifecycle-based app locking.
- `lib/core/widgets/`: Reusable common widgets.
- `lib/app/routes/`: GoRouter route names and configuration.
- `lib/app/theme/`: Light and dark themes.

This separation keeps UI code focused on display, providers focused on state,
and repositories focused on data access.

## 4. Application Startup and Navigation

`main.dart` initializes Flutter, initializes `HiveDatabase.instance.init()`, loads `SharedPreferences`, overrides the theme
persistence dependency, and wraps the app in Riverpod's `ProviderScope`.

`SmartKhataApp` builds `MaterialApp.router`, applies light/dark themes, English
or Urdu locale, GoRouter, and `AppLifecycleLock`.

The startup provider initializes the local environment and chooses the initial destination:

1. Onboarding if onboarding is incomplete.
2. Business setup if no business exists yet.
3. Main application if business setup is complete.

The main screen uses an `IndexedStack` so tab state is retained. Its five tabs
are Home, Customers, Cashbook, Reports, and Settings. Additional pages are
opened through GoRouter, including transactions, reminders, notifications,
search, profile, app lock, backup/restore, and support.

## 5. Main Features and Screens

- **Onboarding:** Introductory flow and English/Urdu language selection.
- **Business setup:** Business identity, owner details, type, phone, address,
  city, currency, and logo.
- **Dashboard/Home:** Receivable, payable, cash, recent activity, shortcuts,
  reminders, and notification information.
- **Customers/Suppliers:** Search, filter, add, edit, archive/delete, opening
  balance, details, and transaction history.
- **Transactions:** Record `gave` or `received` entries, payment method,
  description, date, and receipt. Customer and business totals are updated.
- **Cashbook:** Cash-in/cash-out entries, categories, date filters, balance, and receipts.
- **Reports:** Period filtering, financial metrics, cash-flow charts, risk and
  comparison information.
- **Statements:** Build customer statements and generate, preview,
  print, or share PDF files.
- **Reminders:** Payment due dates, pending/upcoming/completed/overdue states,
  and scheduled local notifications.
- **Global search:** Searches customers, transactions, and cashbook entries.
- **Notifications:** Local notification list and unread count.
- **Settings:** Theme, language, user/business profile, backup/restore, support,
  app lock, and account data reset.
- **Backup/restore:** Full JSON backup files exported and restored locally.

## 6. Riverpod State Management

Riverpod is both the state-management system and dependency-injection layer.
The root `ProviderScope` makes providers available throughout the widget tree.

### Provider types used

- `Provider`: Synchronous dependencies or derived values, such as repositories,
  the current user, and filtered summaries.
- `StreamProvider`: Real-time Hive streams, such as the
  current business, customers, cashbook entries, dashboard, and notifications.
- `FutureProvider`: One-time asynchronous data, such as a generated customer statement.
- `NotifierProvider`: Editable form state, filters, selected navigation tab,
  and synchronous action state.
- `AsyncNotifierProvider`: Asynchronous workflows such as startup, backup,
  account reset, app lock, and customer actions.
- `family`: Creates state for a supplied argument, such as a customer ID or
  statement request.

Important provider groups include:

- `app_providers.dart`: Central repositories and core application providers.
- `startup_providers.dart`: Initial database initialization and route decision.
- `business_providers.dart`: Current business stream.
- `customer_providers.dart`: Customer list, filters, totals, and actions.
- `transaction_providers.dart`: Transaction streams and mutations.
- `cashbook_providers.dart`: Cashbook stream, filtering, summaries, and actions.
- `dashboard_providers.dart`/`report_providers.dart`: Aggregated financial views.
- `settings_providers.dart`: Theme and settings state.
- `app_lock_providers.dart`: PIN, biometrics, and unlock state.
- `backup_providers.dart`: Backup creation, restore, deletion, and progress.

## 7. Local Storage & Hive Architecture

### Hive Database Boxes

| Box Name | Stored Data |
| --- | --- |
| `users` | Profile, selected business, language, theme, and preferences |
| `businesses` | Business details and financial totals |
| `customers` | Customers/suppliers and current balances |
| `transactions` | Gave/received ledger entries |
| `cashbook_entries` | Cash-in and cash-out entries |
| `reminders` | Payment reminders and status |
| `notifications` | User notifications and read state |
| `backups` | Backup file metadata |
| `support_requests` | Support form submissions |

### Local File Storage

Local files (business logos, receipts, statements, and JSON backup files) are stored
directly in the application's local documents directory (`storage/receipts`, `storage/logos`, `backups`).

## 8. Running the Project

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```
