import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_service.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  AuthMethod _currentAuthMethod = AuthMethod.pin;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  /// 인증 시스템 초기화
  Future<void> _initializeAuth() async {
    try {
      // 생체인증 사용 가능 여부 확인
      final biometricAvailable = await AuthService.isBiometricAvailable();
      final biometricEnabled = await AuthService.isBiometricEnabled();
      final currentAuthMethod = await AuthService.getAuthMethod();
      final availableBiometrics = await AuthService.getAvailableBiometrics();
      
      setState(() {
        _biometricAvailable = biometricAvailable;
        _biometricEnabled = biometricEnabled;
        _currentAuthMethod = currentAuthMethod;
        _availableBiometrics = availableBiometrics;
      });

      print('🔐 [INIT] 생체인증 사용 가능: $_biometricAvailable');
      print('🔐 [INIT] 생체인증 활성화: $_biometricEnabled');
      print('🔐 [INIT] 현재 인증 방법: $_currentAuthMethod');
      print('🔐 [INIT] 사용 가능한 생체인증: ${_availableBiometrics.map((e) => AuthService.getBiometricTypeDisplayName(e)).join(', ')}');

      // 생체인증이 설정되어 있다면 자동으로 실행
      if (_currentAuthMethod == AuthMethod.biometric && _biometricEnabled && _biometricAvailable) {
        _loginWithBiometric();
      }
    } catch (e) {
      print('❌ [INIT] 인증 시스템 초기화 오류: $e');
    }
  }

  /// PIN으로 로그인
  Future<void> _loginWithPin(String pin) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔐 [LOGIN] PIN 로그인 시도: "$pin"');
      final isValid = await AuthService.verifyPin(pin);
      
      if (isValid) {
        print('🔐 [LOGIN] ✅ PIN 로그인 성공! 메모 앱으로 이동');
        await _navigateToMainApp(pin);
      } else {
        _showErrorMessage('PIN이 올바르지 않습니다.');
        _pinController.clear();
      }
    } catch (e) {
      _showErrorMessage('PIN 로그인 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 지문인증으로 로그인
  Future<void> _loginWithBiometric() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('👆 [LOGIN] 지문인증 로그인 시도');
      final authenticated = await AuthService.authenticateWithBiometric();
      
      if (authenticated) {
        print('👆 [LOGIN] ✅ 지문인증 성공! 메모 앱으로 이동');
        // 지문인증 성공 시 저장된 PIN을 가져와서 세션 설정
        final prefs = await SharedPreferences.getInstance();
        final savedPin = prefs.getString('app_pin') ?? '1234'; // 기본값
        await _navigateToMainApp(savedPin);
      } else {
        _showErrorMessage('지문인증에 실패했습니다. PIN으로 로그인해주세요.');
      }
    } catch (e) {
      _showErrorMessage('지문인증 중 오류가 발생했습니다: $e');
      print('❌ [LOGIN] 지문인증 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 메인 앱으로 이동
  Future<void> _navigateToMainApp(String pin) async {
    // 세션 PIN 설정
    DataService.setSessionPin(pin);
    // 기존 MemoListScreen으로 이동
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => MemoListScreen()),
    );
  }

  /// 인증 방법 전환
  void _switchAuthMethod() {
    setState(() {
      if (_currentAuthMethod == AuthMethod.pin) {
        _currentAuthMethod = AuthMethod.biometric;
      } else {
        _currentAuthMethod = AuthMethod.pin;
      }
    });
  }

  /// 오류 메시지 표시
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _currentAuthMethod == AuthMethod.biometric && _biometricEnabled
              ? '👆 지문인증 로그인'
              : '🔒 PIN 로그인',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[850],
        elevation: 0,
        actions: [
          // 인증 방법 전환 버튼
          if (_biometricAvailable)
            IconButton(
              icon: Icon(
                _currentAuthMethod == AuthMethod.biometric
                    ? Icons.pin
                    : Icons.fingerprint,
                color: Colors.white,
              ),
              onPressed: _switchAuthMethod,
              tooltip: _currentAuthMethod == AuthMethod.biometric
                  ? 'PIN으로 전환'
                  : '지문인증으로 전환',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _currentAuthMethod == AuthMethod.biometric && _biometricEnabled
                  ? Icons.fingerprint
                  : Icons.security,
              size: 80,
              color: Colors.teal,
            ),
            SizedBox(height: 24),
            Text(
              '안전한 메모장',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _currentAuthMethod == AuthMethod.biometric && _biometricEnabled
                  ? (_availableBiometrics.isNotEmpty
                      ? '${_availableBiometrics.map((e) => AuthService.getBiometricTypeDisplayName(e)).join(', ')}을 사용해주세요'
                      : '지문인증을 사용해주세요')
                  : 'PIN 번호를 입력해주세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 48),
            
            // 지문인증 UI
            if (_currentAuthMethod == AuthMethod.biometric && _biometricEnabled) ...[
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.teal, width: 2),
                  color: Colors.grey[850],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(60),
                  onTap: _isLoading ? null : _loginWithBiometric,
                  child: Icon(
                    Icons.fingerprint,
                    size: 60,
                    color: _isLoading ? Colors.grey : Colors.teal,
                  ),
                ),
              ),
              SizedBox(height: 24),
              if (!_isLoading)
                ElevatedButton(
                  onPressed: _loginWithBiometric,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text('지문인증 시작'),
                ),
            ]
            
            // PIN 입력 UI
            else ...[
              // PIN 입력 필드
              Pinput(
                controller: _pinController,
                length: 4,
                obscureText: true,
                autofocus: true,
                enabled: !_isLoading,
                onChanged: (value) {
                  print('🔤 [PIN INPUT] 입력값: "$value"');
                },
                onCompleted: _loginWithPin,
                defaultPinTheme: PinTheme(
                  width: 56,
                  height: 56,
                  textStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[600]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                focusedPinTheme: PinTheme(
                  width: 56,
                  height: 56,
                  textStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.teal, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              
              SizedBox(height: 32),
              
              // 직접 테스트 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : () => _loginWithPin('1234'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text('1234로 직접 로그인'),
              ),
            ],
            
            SizedBox(height: 32),
            
            if (_isLoading) ...[
              CircularProgressIndicator(color: Colors.teal),
              SizedBox(height: 16),
              Text(
                _currentAuthMethod == AuthMethod.biometric && _biometricEnabled
                    ? '지문인증 중...'
                    : '로그인 중...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
            
            // 사용 가능한 인증 방법 표시
            if (_biometricAvailable && _availableBiometrics.isNotEmpty) ...[
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '사용 가능한 인증 방법',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• PIN 번호\n• ${_availableBiometrics.map((e) => AuthService.getBiometricTypeDisplayName(e)).join(', ')}',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

 