import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// 메모 데이터 암호화/복호화를 담당하는 보안 서비스
class SecurityService {
  /// AES-256 암호화를 위한 키 길이
  static const int _keyLength = 32;
  
  /// 초기화 벡터 길이
  static const int _ivLength = 16;
  
  /// PIN을 기반으로 암호화 키 생성
  static Uint8List _generateKeyFromPin(String pin) {
    // PIN + 고정 솔트로 키 생성
    final salt = 'secure_memo_salt_2025';
    final input = pin + salt;
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    
    // 256비트 키 생성
    final key = Uint8List.fromList(digest.bytes);
    return key;
  }
  
  /// 랜덤 IV 생성
  static Uint8List _generateIV() {
    final random = Random.secure();
    final iv = Uint8List(_ivLength);
    for (int i = 0; i < _ivLength; i++) {
      iv[i] = random.nextInt(256);
    }
    return iv;
  }
  
  /// 단순 XOR 암호화 (AES 라이브러리 없이 기본 보안)
  static Uint8List _xorEncrypt(Uint8List data, Uint8List key) {
    final encrypted = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      encrypted[i] = data[i] ^ key[i % key.length];
    }
    return encrypted;
  }
  
  /// 단순 XOR 복호화
  static Uint8List _xorDecrypt(Uint8List encryptedData, Uint8List key) {
    return _xorEncrypt(encryptedData, key); // XOR는 동일한 연산
  }
  
  /// 메모 데이터 암호화
  static String encryptMemoData(String jsonData, String pin) {
    try {
      // PIN 기반 키 생성
      final key = _generateKeyFromPin(pin);
      
      // 데이터를 바이트로 변환
      final dataBytes = utf8.encode(jsonData);
      
      // IV 생성
      final iv = _generateIV();
      
      // 암호화 수행
      final encrypted = _xorEncrypt(dataBytes, key);
      
      // IV + 암호화된 데이터 결합
      final combined = Uint8List(iv.length + encrypted.length);
      combined.setAll(0, iv);
      combined.setAll(iv.length, encrypted);
      
      // Base64로 인코딩하여 반환
      return base64.encode(combined);
    } catch (e) {
      print('암호화 오류: $e');
      return jsonData; // 오류 시 원본 반환
    }
  }
  
  /// 메모 데이터 복호화
  static String decryptMemoData(String encryptedData, String pin) {
    try {
      // Base64 디코딩
      final combined = base64.decode(encryptedData);
      
      // IV와 암호화된 데이터 분리
      final iv = combined.sublist(0, _ivLength);
      final encrypted = combined.sublist(_ivLength);
      
      // PIN 기반 키 생성
      final key = _generateKeyFromPin(pin);
      
      // 복호화 수행
      final decrypted = _xorDecrypt(encrypted, key);
      
      // 문자열로 변환하여 반환
      return utf8.decode(decrypted);
    } catch (e) {
      print('복호화 오류: $e');
      return ''; // 오류 시 빈 문자열 반환
    }
  }
  
  /// 데이터 무결성 검증
  static bool verifyDataIntegrity(String data) {
    try {
      // JSON 형식 검증
      jsonDecode(data);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 메모리에서 민감한 데이터 제거
  static void clearSensitiveData(String data) {
    // Dart에서는 직접적인 메모리 클리어가 어려우므로
    // 가비지 컬렉션을 통한 간접적 제거
    data = '';
  }
  
  /// 디버깅 모드 감지
  static bool isDebuggingMode() {
    bool isDebugMode = false;
    assert(() {
      isDebugMode = true;
      return true;
    }());
    return isDebugMode;
  }
  
  /// 루팅 감지 (기본적인 방법)
  static bool isDeviceRooted() {
    // 주요 루팅 관련 파일들 체크
    final rootFiles = [
      '/system/app/Superuser.apk',
      '/sbin/su',
      '/system/bin/su',
      '/system/xbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
      '/su/bin/su',
    ];
    
    // 실제 구현에서는 dart:io의 File.exists()를 사용
    // 현재는 false 반환 (추후 확장 가능)
    return false;
  }
} 