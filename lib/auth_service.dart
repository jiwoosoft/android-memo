import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// 인증 방법 열거형
enum AuthMethod {
  pin,        // PIN 번호 인증
  biometric,  // 지문/생체 인증
}

/// 인증 서비스 클래스
/// PIN 인증과 지문인증을 통합 관리합니다.
class AuthService {
  static const String _pinKey = 'app_pin';
  static const String _authMethodKey = 'auth_method';
  static const String _biometricEnabledKey = 'biometric_enabled';
  
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// 생체인증 사용 가능 여부 확인
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      print('생체인증 사용 가능 여부 확인 중 오류: $e');
      return false;
    }
  }

  /// 사용 가능한 생체인증 방법 목록 조회
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('사용 가능한 생체인증 방법 조회 중 오류: $e');
      return [];
    }
  }

  /// PIN 저장 (해시화하여 저장)
  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hashedPin = sha256.convert(utf8.encode(pin)).toString();
    await prefs.setString(_pinKey, hashedPin);
    print('PIN 저장 완료');
  }

  /// PIN 검증
  static Future<bool> verifyPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHashedPin = prefs.getString(_pinKey);
      if (storedHashedPin == null) return false;
      
      final hashedPin = sha256.convert(utf8.encode(pin)).toString();
      return storedHashedPin == hashedPin;
    } catch (e) {
      print('PIN 검증 중 오류: $e');
      return false;
    }
  }

  /// PIN 설정 여부 확인
  static Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) != null;
  }

  /// 현재 설정된 인증 방법 조회
  static Future<AuthMethod> getAuthMethod() async {
    final prefs = await SharedPreferences.getInstance();
    final methodString = prefs.getString(_authMethodKey) ?? 'pin';
    return methodString == 'biometric' ? AuthMethod.biometric : AuthMethod.pin;
  }

  /// 인증 방법 설정
  static Future<void> setAuthMethod(AuthMethod method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authMethodKey, method == AuthMethod.biometric ? 'biometric' : 'pin');
    print('인증 방법 설정: ${method == AuthMethod.biometric ? '생체인증' : 'PIN'}');
  }

  /// 생체인증 활성화 여부 확인
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// 생체인증 활성화/비활성화 설정
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
    print('생체인증 설정: ${enabled ? '활성화' : '비활성화'}');
  }

  /// 생체인증 실행
  static Future<bool> authenticateWithBiometric() async {
    try {
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        print('생체인증을 사용할 수 없습니다.');
        return false;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: '앱에 접근하려면 생체인증을 완료해주세요.',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      print('생체인증 결과: ${didAuthenticate ? '성공' : '실패'}');
      return didAuthenticate;
    } catch (e) {
      print('생체인증 중 오류: $e');
      return false;
    }
  }

  /// 통합 인증 실행
  /// 설정된 인증 방법에 따라 PIN 또는 생체인증을 실행합니다.
  static Future<bool> authenticate({String? pin}) async {
    try {
      final authMethod = await getAuthMethod();
      
      if (authMethod == AuthMethod.biometric) {
        final biometricEnabled = await isBiometricEnabled();
        if (biometricEnabled) {
          return await authenticateWithBiometric();
        } else {
          // 생체인증이 비활성화된 경우 PIN으로 폴백
          if (pin != null) {
            return await verifyPin(pin);
          }
          return false;
        }
      } else {
        // PIN 인증
        if (pin != null) {
          return await verifyPin(pin);
        }
        return false;
      }
    } catch (e) {
      print('인증 중 오류: $e');
      return false;
    }
  }

  /// 인증 설정 초기화 (앱 재설치 시 등)
  static Future<void> resetAuthSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.remove(_authMethodKey);
    await prefs.remove(_biometricEnabledKey);
    await _secureStorage.deleteAll();
    print('인증 설정이 초기화되었습니다.');
  }

  /// 생체인증 타입을 한글로 변환
  static String getBiometricTypeDisplayName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return '얼굴 인식';
      case BiometricType.fingerprint:
        return '지문 인식';
      case BiometricType.iris:
        return '홍채 인식';
      case BiometricType.weak:
        return '기본 생체인증';
      case BiometricType.strong:
        return '강화 생체인증';
      default:
        return '생체인증';
    }
  }
} 