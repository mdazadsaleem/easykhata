# Easy Khata (Smart Khata)

A fast, offline-first bookkeeping and ledger management application built with Flutter, Riverpod, and Hive.

## Architecture

- **Local Database**: Hive (`hive` and `hive_flutter`) for secure, high-performance local NoSQL storage.
- **State Management**: Flutter Riverpod (`flutter_riverpod`).
- **Local Storage**: Application documents directory for receipts and business logos.
- **Preferences & Settings**: SharedPreferences for themes, languages, and app configurations.
- **No Cloud Required**: Runs 100% offline without any external authentication or Firebase requirements.

## Features

- **Ledger Management**: Customer and supplier accounts with automatic balance calculation (Money Given / Money Received).
- **Daily Cashbook**: Track daily cash in and cash out transactions.
- **Customer Statement Reports**: Generate and export detailed PDF statements.
- **Payment Reminders**: Set reminders and track overdue balances.
- **Local Backup & Restore**: Export full JSON backups and restore records anytime.
- **Multi-language Support**: English and Urdu.
- **App Lock**: Biometric and PIN protection.

## Run

```sh
flutter pub get
flutter analyze
flutter run
```
