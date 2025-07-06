import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// 인증 방법 열거형 (PIN 전용)
enum AuthMethod {
  pin, // PIN 번호 인증만 지원
}

/// 인증 서비스 클래스
/// PIN 기반 인증을 담당합니다.
class AuthService {
  static const String _pinKey = 'app_pin';
  static const String _authMethodKey = 'auth_method';
  
  // SecureStorage 인스턴스
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// PIN 저장
  static Future<void> savePin(String pin) async {
    try {
      print('🔐 [AUTH] PIN 저장 시작: 길이=${pin.length}');
      
      // UTF-8 인코딩으로 PIN을 바이트로 변환
      final pinBytes = utf8.encode(pin);
      print('🔐 [AUTH] PIN 바이트 변환: ${pinBytes.length}바이트');
      
      // SHA-256 해시 생성
      final hashedPin = sha256.convert(pinBytes).toString();
      print('🔐 [AUTH] PIN 해시 생성: ${hashedPin.substring(0, 8)}...');
      
      // SharedPreferences에 해시된 PIN 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinKey, hashedPin);
      print('🔐 [AUTH] SharedPreferences에 PIN 저장 완료');
      
      // SecureStorage에 원본 PIN 백업 저장 (복구용)
      await _secureStorage.write(key: '${_pinKey}_secure', value: pin);
      print('🔐 [AUTH] SecureStorage에 PIN 백업 저장 완료');
      
      // 저장 즉시 검증
      final savedHash = prefs.getString(_pinKey);
      final backupPin = await _secureStorage.read(key: '${_pinKey}_secure');
      
      if (savedHash == hashedPin && backupPin == pin) {
        print('✅ [AUTH] PIN 저장 및 검증 성공');
      } else {
        print('❌ [AUTH] PIN 저장 검증 실패');
        throw Exception('PIN 저장 후 검증에 실패했습니다.');
      }
      
    } catch (e) {
      print('❌ [AUTH] PIN 저장 중 오류: $e');
      rethrow;
    }
  }

  /// PIN 검증
  static Future<bool> verifyPin(String pin) async {
    try {
      print('🔐 [AUTH] PIN 검증 시작: 길이=${pin.length}');
      
      final prefs = await SharedPreferences.getInstance();
      final savedHashedPin = prefs.getString(_pinKey);
      
      if (savedHashedPin == null) {
        print('❌ [AUTH] 저장된 PIN이 없습니다.');
        return false;
      }
      
      // 입력된 PIN을 해시화
      final pinBytes = utf8.encode(pin);
      final inputHashedPin = sha256.convert(pinBytes).toString();
      
      print('🔐 [AUTH] 저장된 해시: ${savedHashedPin.substring(0, 8)}...');
      print('🔐 [AUTH] 입력된 해시: ${inputHashedPin.substring(0, 8)}...');
      
      // 1차 검증: 해시 비교
      if (savedHashedPin == inputHashedPin) {
        print('✅ [AUTH] PIN 검증 성공 (해시 일치)');
        return true;
      }
      
      // 2차 검증: SecureStorage의 원본과 비교 (복구 메커니즘)
      try {
        final backupPin = await _secureStorage.read(key: '${_pinKey}_secure');
        if (backupPin != null && backupPin == pin) {
          print('✅ [AUTH] PIN 검증 성공 (백업과 일치)');
          
          // 주 저장소 복구
          await savePin(pin);
          print('🔄 [AUTH] 주 저장소 복구 완료');
          
          return true;
        }
      } catch (e) {
        print('⚠️ [AUTH] 백업 PIN 확인 중 오류: $e');
      }
      
      print('❌ [AUTH] PIN 검증 실패');
      return false;
      
    } catch (e) {
      print('❌ [AUTH] PIN 검증 중 오류: $e');
      return false;
    }
  }

  /// PIN 설정 여부 확인
  static Future<bool> isPinSet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPin = prefs.containsKey(_pinKey);
      print('🔐 [AUTH] PIN 설정 여부: $hasPin');
      return hasPin;
    } catch (e) {
      print('❌ [AUTH] PIN 설정 확인 중 오류: $e');
      return false;
    }
  }

  /// 인증 방법 저장 (항상 PIN으로 설정)
  static Future<void> setAuthMethod(AuthMethod method) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_authMethodKey, AuthMethod.pin.toString());
      print('🔐 [AUTH] 인증 방법 설정: PIN 전용');
    } catch (e) {
      print('❌ [AUTH] 인증 방법 설정 중 오류: $e');
      rethrow;
    }
  }

  /// 인증 방법 조회 (항상 PIN 반환)
  static Future<AuthMethod> getAuthMethod() async {
    return AuthMethod.pin; // 항상 PIN 반환
  }

  /// 통합 인증 실행 (PIN만 지원)
  static Future<bool> authenticate({String? pin}) async {
    try {
      if (pin != null) {
        return await verifyPin(pin);
      }
      return false;
    } catch (e) {
      print('❌ [AUTH] 인증 중 오류: $e');
      return false;
    }
  }

  /// 인증 설정 초기화 (앱 재설치 시 등)
  static Future<void> resetAuthSettings() async {
    try {
      print('🔄 [AUTH] 인증 설정 초기화 시작');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pinKey);
      await prefs.remove(_authMethodKey);
      
      // SecureStorage도 완전 삭제
      await _secureStorage.delete(key: '${_pinKey}_secure');
      await _secureStorage.deleteAll();
      
      print('✅ [AUTH] 인증 설정이 완전히 초기화되었습니다.');
    } catch (e) {
      print('❌ [AUTH] 인증 설정 초기화 중 오류: $e');
      rethrow;
    }
  }
} 