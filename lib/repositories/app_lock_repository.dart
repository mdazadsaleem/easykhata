import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppLockRepository {
  AppLockRepository(this._storage, this._localAuth);

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _legacyPinKey = 'app_lock_pin';
  static const _pinHashKey = 'app_lock_pin_hash_v2';
  static const _pinSaltKey = 'app_lock_pin_salt_v2';
  static const _biometricKey = 'app_lock_biometric';
  static const _minimizedKey = 'app_lock_when_minimized';
  static const _timeoutKey = 'app_lock_timeout';
  static const _failedAttemptsKey = 'app_lock_failed_attempts';
  static const _lockoutUntilKey = 'app_lock_lockout_until';
  static const _hashRounds = 25000;

  Future<bool> hasPin() async {
    if (await _storage.containsKey(key: _pinHashKey)) return true;
    final legacy = await _storage.read(key: _legacyPinKey);
    if (legacy != null && RegExp(r'^\d{4}$').hasMatch(legacy)) {
      await savePin(legacy);
      await _storage.delete(key: _legacyPinKey);
      return true;
    }
    return false;
  }

  Future<void> savePin(String pin) async {
    _validatePin(pin);
    final random = Random.secure();
    final salt = List<int>.generate(32, (_) => random.nextInt(256));
    final hash = _deriveHash(pin, salt);
    await _storage.write(key: _pinSaltKey, value: base64Encode(salt));
    await _storage.write(key: _pinHashKey, value: base64Encode(hash));
    await _storage.delete(key: _legacyPinKey);
  }

  Future<bool> verifyPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) return false;
    if (!await hasPin()) return false;
    final savedHash = await _storage.read(key: _pinHashKey);
    final savedSalt = await _storage.read(key: _pinSaltKey);
    if (savedHash == null || savedSalt == null) return false;
    final actual = _deriveHash(pin, base64Decode(savedSalt));
    return _constantTimeEquals(actual, base64Decode(savedHash));
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _legacyPinKey);
    await setBiometricEnabled(false);
  }

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.isDeviceSupported() &&
          (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometrically() async {
    if (!await canUseBiometrics()) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock Smart Khata',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> biometricEnabled() => readBool(_biometricKey, fallback: false);

  Future<void> setBiometricEnabled(bool value) =>
      writeBool(_biometricKey, value);

  Future<bool> readBool(String key, {bool fallback = false}) async {
    final stored = await _storage.read(key: key);
    return stored == null ? fallback : stored.toLowerCase() == 'true';
  }

  Future<void> writeBool(String key, bool value) =>
      _storage.write(key: key, value: value.toString());

  Future<String> readTimeout() async =>
      await _storage.read(key: _timeoutKey) ?? '5 minutes';

  Future<void> writeTimeout(String value) =>
      _storage.write(key: _timeoutKey, value: value);

  Future<int> readFailedAttempts() async =>
      int.tryParse(await _storage.read(key: _failedAttemptsKey) ?? '') ?? 0;

  Future<DateTime?> readLockoutUntil() async =>
      DateTime.tryParse(await _storage.read(key: _lockoutUntilKey) ?? '');

  Future<void> saveAttemptState(int attempts, DateTime? lockoutUntil) async {
    await _storage.write(key: _failedAttemptsKey, value: '$attempts');
    if (lockoutUntil == null) {
      await _storage.delete(key: _lockoutUntilKey);
    } else {
      await _storage.write(
        key: _lockoutUntilKey,
        value: lockoutUntil.toUtc().toIso8601String(),
      );
    }
  }

  String get minimizedKey => _minimizedKey;

  List<int> _deriveHash(String pin, List<int> salt) {
    List<int> value = utf8.encode(pin);
    for (var round = 0; round < _hashRounds; round++) {
      value = Hmac(sha256, salt).convert(value).bytes;
    }
    return value;
  }

  bool _constantTimeEquals(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }

  void _validatePin(String pin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN must contain exactly four digits.');
    }
  }
}
