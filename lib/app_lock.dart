import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Cách mở khoá: sinh trắc học, mật mã máy (khi sinh trắc học bị tắt quyền/tạm khoá và chưa có PIN),
/// mã PIN của app, hoặc không còn cách nào (chỉ đăng xuất).
enum LockMethod { biometric, device, pin, none }

sealed class PinResult {
  const PinResult();
}

class PinOk extends PinResult {
  const PinOk();
}

class PinWrong extends PinResult {
  const PinWrong(this.remaining);
  final int remaining;
}

class PinExhausted extends PinResult {
  const PinExhausted();
}

class PinMissing extends PinResult {
  const PinMissing();
}

/// Xác thực bước 2 trên máy: sinh trắc học (Face ID/Touch ID/vân tay) nếu máy có,
/// không thì mã PIN 4 số của app (hash + salt trong Keychain/Keystore).
class AppLock {
  /// Ở nền lâu hơn mức này thì khi quay lại phải mở khoá.
  static const lockAfter = Duration(minutes: 10);
  static const pinLength = 4;
  static const maxPinAttempts = 10;

  // this_device: không theo bản sao lưu sang máy khác.
  static const _secure = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
  );
  static const _pinKey = 'pinHash';
  static const _failKey = 'pinFails';

  final _auth = LocalAuthentication();

  Future<List<BiometricType>> _biometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> hasBiometrics() async => (await _biometrics()).isNotEmpty;

  /// Tên hiển thị trên nút mở khoá.
  Future<String> biometricLabel() async {
    final types = await _biometrics();
    if (types.contains(BiometricType.face)) return 'Face ID';
    if (types.contains(BiometricType.fingerprint)) return 'vân tay';
    return 'sinh trắc học';
  }

  Future<bool> hasPin() async {
    try {
      return (await _secure.read(key: _pinKey))?.isNotEmpty ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Chỉ gọi ngay sau khi đăng nhập bằng mật khẩu: máy không có sinh trắc học và chưa có PIN.
  /// Không dùng khi đang khoá, nếu không tắt quyền Face ID của app là tạo được PIN mới để vượt khoá.
  Future<bool> needsPinSetup() async => !await hasBiometrics() && !await hasPin();

  /// Cách mở khoá khi đang khoá. Sinh trắc học bị tắt quyền/tạm khoá mà chưa có PIN thì dùng mật mã máy.
  Future<LockMethod> unlockMethod() async {
    if (await hasBiometrics()) return LockMethod.biometric;
    if (await hasPin()) return LockMethod.pin;
    try {
      if (await _auth.isDeviceSupported()) return LockMethod.device;
    } catch (_) {}
    return LockMethod.none;
  }

  /// `null` = thành công; ngược lại là thông báo lỗi tiếng Việt.
  /// `biometricOnly: false` để hệ điều hành cho dùng mật mã máy khi sinh trắc học lỗi nhiều lần.
  Future<String?> authenticate() async {
    try {
      final ok = await _auth.authenticate(localizedReason: 'Mở khoá terminal', biometricOnly: false);
      return ok ? null : 'Chưa xác thực được. Bấm để thử lại.';
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout => 'Đã huỷ. Bấm để thử lại.',
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => 'Sinh trắc học đang bị khoá tạm, thử lại để nhập mật mã máy.',
        LocalAuthExceptionCode.noCredentialsSet => 'Máy chưa đặt mật mã. Đăng xuất để đăng nhập lại.',
        LocalAuthExceptionCode.authInProgress => 'Đang xác thực…',
        _ => 'Không xác thực được (${e.code.name}). Bấm để thử lại.',
      };
    } catch (_) {
      return 'Không xác thực được. Bấm để thử lại.';
    }
  }

  Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    await _secure.write(key: _pinKey, value: '$salt:${_hash(salt, pin)}');
    await _secure.delete(key: _failKey);
  }

  Future<PinResult> verifyPin(String pin) async {
    final stored = await _secure.read(key: _pinKey);
    final sep = stored?.indexOf(':') ?? -1;
    if (stored == null || sep < 0) return const PinMissing();
    final salt = stored.substring(0, sep);
    if (_hash(salt, pin) == stored.substring(sep + 1)) {
      await _secure.delete(key: _failKey);
      return const PinOk();
    }
    final fails = (int.tryParse(await _secure.read(key: _failKey) ?? '') ?? 0) + 1;
    if (fails >= maxPinAttempts) {
      await clear();
      return const PinExhausted();
    }
    await _secure.write(key: _failKey, value: '$fails');
    return PinWrong(maxPinAttempts - fails);
  }

  /// Xoá mã PIN và bộ đếm sai.
  Future<void> clear() async {
    try {
      await _secure.delete(key: _pinKey);
      await _secure.delete(key: _failKey);
    } catch (_) {}
  }

  static String _hash(String salt, String pin) => sha256.convert(utf8.encode('$salt:$pin')).toString();
}
