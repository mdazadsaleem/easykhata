import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../repositories/app_lock_repository.dart';

class AppLockSettings {
  const AppLockSettings({
    this.hasPin = false,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.lockWhenMinimized = true,
    this.timeout = '5 minutes',
    this.error,
  });

  final bool hasPin;
  final bool biometricEnabled;
  final bool biometricAvailable;
  final bool lockWhenMinimized;
  final String timeout;
  final String? error;

  bool get fingerprint => biometricEnabled;
  bool get faceId => biometricEnabled;

  AppLockSettings copyWith({
    bool? hasPin,
    bool? biometricEnabled,
    bool? biometricAvailable,
    bool? lockWhenMinimized,
    String? timeout,
    String? error,
  }) => AppLockSettings(
    hasPin: hasPin ?? this.hasPin,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    lockWhenMinimized: lockWhenMinimized ?? this.lockWhenMinimized,
    timeout: timeout ?? this.timeout,
    error: error,
  );
}

final appLockRepositoryProvider = Provider(
  (_) => AppLockRepository(const FlutterSecureStorage(), LocalAuthentication()),
);

final appLockSettingsProvider =
    AsyncNotifierProvider<AppLockNotifier, AppLockSettings>(
      AppLockNotifier.new,
    );

class AppLockNotifier extends AsyncNotifier<AppLockSettings> {
  AppLockRepository get _repository => ref.read(appLockRepositoryProvider);

  @override
  Future<AppLockSettings> build() async => AppLockSettings(
    hasPin: await _repository.hasPin(),
    biometricEnabled: await _repository.biometricEnabled(),
    biometricAvailable: await _repository.canUseBiometrics(),
    lockWhenMinimized: await _repository.readBool(
      _repository.minimizedKey,
      fallback: true,
    ),
    timeout: await _repository.readTimeout(),
  );

  Future<void> savePin(String pin) async {
    await _repository.savePin(pin);
    state = AsyncData(
      (state.value ?? const AppLockSettings()).copyWith(
        hasPin: true,
        error: null,
      ),
    );
    ref.read(appUnlockProvider.notifier).disableLock();
  }

  Future<bool> verifyPin(String pin) => _repository.verifyPin(pin);

  Future<void> removePin(String currentPin) async {
    if (!await _repository.verifyPin(currentPin)) {
      throw StateError('The current PIN is incorrect.');
    }
    await _repository.removePin();
    state = AsyncData(
      (state.value ?? const AppLockSettings()).copyWith(
        hasPin: false,
        biometricEnabled: false,
      ),
    );
    ref.read(appUnlockProvider.notifier).disableLock();
  }

  Future<void> setBiometric(bool value) async {
    final current = state.value ?? const AppLockSettings();
    if (value) {
      if (!current.hasPin) {
        state = AsyncData(
          current.copyWith(error: 'Create a PIN before enabling biometrics.'),
        );
        return;
      }
      if (!await _repository.canUseBiometrics()) {
        state = AsyncData(
          current.copyWith(
            biometricAvailable: false,
            error: 'Biometric authentication is unavailable on this device.',
          ),
        );
        return;
      }
      if (!await _repository.authenticateBiometrically()) {
        state = AsyncData(
          current.copyWith(error: 'Biometric verification was not completed.'),
        );
        return;
      }
    }
    await _repository.setBiometricEnabled(value);
    state = AsyncData(
      current.copyWith(
        biometricEnabled: value,
        biometricAvailable: value ? true : current.biometricAvailable,
        error: null,
      ),
    );
  }

  Future<void> setFingerprint(bool value) => setBiometric(value);
  Future<void> setFaceId(bool value) => setBiometric(value);

  Future<void> setLockWhenMinimized(bool value) async {
    await _repository.writeBool(_repository.minimizedKey, value);
    state = AsyncData(
      (state.value ?? const AppLockSettings()).copyWith(
        lockWhenMinimized: value,
      ),
    );
  }

  Future<void> setTimeout(String value) async {
    const allowed = {'Immediately', '1 minute', '5 minutes', '15 minutes'};
    if (!allowed.contains(value)) return;
    await _repository.writeTimeout(value);
    state = AsyncData(
      (state.value ?? const AppLockSettings()).copyWith(timeout: value),
    );
  }
}

class AppUnlockState {
  const AppUnlockState({
    this.locked = false,
    this.failedAttempts = 0,
    this.lockoutUntil,
    this.error,
    this.authenticating = false,
  });

  final bool locked;
  final int failedAttempts;
  final DateTime? lockoutUntil;
  final String? error;
  final bool authenticating;

  bool get isLockedOut =>
      lockoutUntil != null && lockoutUntil!.isAfter(DateTime.now());

  AppUnlockState copyWith({
    bool? locked,
    int? failedAttempts,
    DateTime? lockoutUntil,
    String? error,
    bool? authenticating,
    bool clearLockout = false,
  }) => AppUnlockState(
    locked: locked ?? this.locked,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockoutUntil: clearLockout ? null : lockoutUntil ?? this.lockoutUntil,
    error: error,
    authenticating: authenticating ?? this.authenticating,
  );
}

final appUnlockProvider =
    AsyncNotifierProvider<AppUnlockNotifier, AppUnlockState>(
      AppUnlockNotifier.new,
    );

class AppUnlockNotifier extends AsyncNotifier<AppUnlockState> {
  AppLockRepository get _repository => ref.read(appLockRepositoryProvider);

  @override
  Future<AppUnlockState> build() async {
    final hasPin = await _repository.hasPin();
    final attempts = await _repository.readFailedAttempts();
    final lockout = await _repository.readLockoutUntil();
    return AppUnlockState(
      locked: hasPin,
      failedAttempts: attempts,
      lockoutUntil: lockout,
    );
  }

  void lock() {
    final current = state.value ?? const AppUnlockState();
    if (ref.read(appLockSettingsProvider).value?.hasPin == true) {
      state = AsyncData(current.copyWith(locked: true, error: null));
    }
  }

  void disableLock() {
    state = const AsyncData(AppUnlockState());
  }

  Future<bool> unlockWithPin(String pin) async {
    var current = state.value ?? const AppUnlockState(locked: true);
    if (current.isLockedOut) {
      state = AsyncData(
        current.copyWith(error: _lockoutMessage(current.lockoutUntil!)),
      );
      return false;
    }
    if (current.lockoutUntil != null) {
      current = current.copyWith(clearLockout: true);
    }
    if (await _repository.verifyPin(pin)) {
      await _repository.saveAttemptState(0, null);
      state = const AsyncData(AppUnlockState());
      return true;
    }
    final attempts = current.failedAttempts + 1;
    DateTime? lockout;
    var message = 'Incorrect PIN. ${5 - attempts} attempts remaining.';
    if (attempts >= 5) {
      lockout = DateTime.now().add(const Duration(seconds: 30));
      message = 'Too many incorrect attempts. Try again in 30 seconds.';
    }
    await _repository.saveAttemptState(attempts >= 5 ? 0 : attempts, lockout);
    state = AsyncData(
      current.copyWith(
        failedAttempts: attempts >= 5 ? 0 : attempts,
        lockoutUntil: lockout,
        error: message,
      ),
    );
    return false;
  }

  Future<bool> unlockWithBiometrics() async {
    final current = state.value ?? const AppUnlockState(locked: true);
    final settings = ref.read(appLockSettingsProvider).value;
    if (settings?.biometricEnabled != true) {
      state = AsyncData(
        current.copyWith(error: 'Biometric unlock is not enabled.'),
      );
      return false;
    }
    state = AsyncData(current.copyWith(authenticating: true, error: null));
    final success = await _repository.authenticateBiometrically();
    if (success) await _repository.saveAttemptState(0, null);
    state = success
        ? const AsyncData(AppUnlockState())
        : AsyncData(
            current.copyWith(
              authenticating: false,
              error: 'Biometric unlock failed. Enter your PIN instead.',
            ),
          );
    return success;
  }

  String _lockoutMessage(DateTime until) {
    final seconds = until.difference(DateTime.now()).inSeconds + 1;
    return 'Too many attempts. Try again in $seconds seconds.';
  }
}
