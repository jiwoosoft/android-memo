import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_service.dart';
import 'main.dart';

/// 로그인 화면
/// PIN 또는 생체인증을 통해 앱에 로그인합니다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final TextEditingController _pinController = TextEditingController();
  AuthMethod _currentAuthMethod = AuthMethod.pin;
  bool _biometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];
  bool _isLoading = false;
  bool _autoTriggeredBiometric = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_autoTriggeredBiometric) {
      // 앱이 다시 활성화될 때 생체인증 자동 실행
      if (_currentAuthMethod == AuthMethod.biometric && _biometricAvailable) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _authenticateWithBiometric();
        });
      }
    }
  }

  /// 인증 초기화
  Future<void> _initializeAuth() async {
    try {
      final authMethod = await AuthService.getAuthMethod();
      final biometricAvailable = await AuthService.isBiometricAvailable();
      final availableBiometrics = await AuthService.getAvailableBiometrics();
      final biometricEnabled = await AuthService.isBiometricEnabled();

      setState(() {
        _currentAuthMethod = authMethod;
        _biometricAvailable = biometricAvailable && biometricEnabled;
        _availableBiometrics = availableBiometrics;
      });

      // 생체인증이 설정되어 있으면 자동으로 실행
      if (_currentAuthMethod == AuthMethod.biometric && _biometricAvailable) {
        Future.delayed(const Duration(milliseconds: 800), () {
          _authenticateWithBiometric();
        });
      }
    } catch (e) {
      print('인증 초기화 중 오류: $e');
    }
  }

  /// PIN으로 로그인
  Future<void> _loginWithPin(String pin) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final isValid = await AuthService.verifyPin(pin);
      
      if (isValid) {
        _navigateToHome();
      } else {
        _showErrorMessage('PIN이 올바르지 않습니다.');
        _pinController.clear();
      }
    } catch (e) {
      _showErrorMessage('로그인 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 생체인증으로 로그인
  Future<void> _authenticateWithBiometric() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _autoTriggeredBiometric = true;
    });

    try {
      final isAuthenticated = await AuthService.authenticateWithBiometric();
      
      if (isAuthenticated) {
        _navigateToHome();
      } else {
        _showErrorMessage('생체인증에 실패했습니다.');
      }
    } catch (e) {
      _showErrorMessage('생체인증 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 인증 방법 전환
  void _switchAuthMethod() {
    setState(() {
      if (_currentAuthMethod == AuthMethod.pin && _biometricAvailable) {
        _currentAuthMethod = AuthMethod.biometric;
        Future.delayed(const Duration(milliseconds: 300), () {
          _authenticateWithBiometric();
        });
      } else {
        _currentAuthMethod = AuthMethod.pin;
      }
      _pinController.clear();
    });
  }

  /// 홈 화면으로 이동
  void _navigateToHome() {
    // 세션 PIN 설정 (메모 저장을 위해 필요)
    // PIN 로그인의 경우에만 세션 PIN 설정
    if (_currentAuthMethod == AuthMethod.pin) {
      DataService.setSessionPin(_pinController.text);
    } else {
      // 생체인증의 경우 저장된 PIN을 가져와서 세션에 설정
      // 실제로는 생체인증 후에도 암호화를 위해 PIN이 필요함
      _setSessionPinForBiometric();
    }
    
    Navigator.of(context).pushReplacementNamed('/');
  }
  
  /// 생체인증 성공 후 세션 PIN 설정
  Future<void> _setSessionPinForBiometric() async {
    // 생체인증 성공 시에도 암호화를 위해 PIN 정보가 필요
    // 임시로 빈 문자열 설정 (실제로는 더 안전한 방법 필요)
    DataService.setSessionPin('');
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

  /// 인증 설정 초기화 확인 다이얼로그
  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⚠️ 인증 설정 초기화'),
          content: const Text(
            '인증 설정을 초기화하면 모든 메모 데이터가 삭제됩니다.\n\n'
            '로그인 문제가 해결되지 않을 때만 사용하세요.\n\n'
            '정말로 초기화하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetAuthSettings();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('초기화'),
            ),
          ],
        );
      },
    );
  }

  /// 인증 설정 초기화 실행
  Future<void> _resetAuthSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 인증 설정 초기화
      await AuthService.resetAuthSettings();
      
      // 앱 데이터 초기화
      await DataService.clearAllData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 인증 설정이 초기화되었습니다. 새로운 PIN을 설정해주세요.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // 인증 설정 화면으로 이동
      Navigator.of(context).pushReplacementNamed('/auth-setup');
    } catch (e) {
      _showErrorMessage('초기화 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 앱 로고 및 제목
                const Icon(
                  Icons.security,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),
                const Text(
                  '보안 메모장',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '안전하게 보호된 메모를 확인하세요',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 48),

                // 인증 방법에 따른 UI
                if (_currentAuthMethod == AuthMethod.pin) ...[
                  _buildPinLoginWidget(),
                ] else ...[
                  _buildBiometricLoginWidget(),
                ],

                const SizedBox(height: 32),

                // 인증 방법 전환 버튼
                if (_biometricAvailable) ...[
                  TextButton.icon(
                    onPressed: _isLoading ? null : _switchAuthMethod,
                    icon: Icon(
                      _currentAuthMethod == AuthMethod.pin 
                          ? Icons.fingerprint 
                          : Icons.lock,
                    ),
                    label: Text(
                      _currentAuthMethod == AuthMethod.pin 
                          ? '생체인증으로 로그인' 
                          : 'PIN으로 로그인',
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // 인증 설정 초기화 버튼
                TextButton.icon(
                  onPressed: _isLoading ? null : _showResetDialog,
                  icon: const Icon(Icons.refresh, color: Colors.red),
                  label: const Text(
                    '인증 설정 초기화',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// PIN 로그인 위젯
  Widget _buildPinLoginWidget() {
    return Column(
      children: [
        const Text(
          'PIN 번호를 입력해주세요',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        Pinput(
          controller: _pinController,
          length: 4,
          obscureText: true,
          autofocus: true,
          enabled: !_isLoading,
          defaultPinTheme: PinTheme(
            width: 56,
            height: 56,
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          focusedPinTheme: PinTheme(
            width: 56,
            height: 56,
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onCompleted: _loginWithPin,
        ),
        if (_isLoading) ...[
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ],
    );
  }

  /// 생체인증 로그인 위젯
  Widget _buildBiometricLoginWidget() {
    return Column(
      children: [
        Text(
          _availableBiometrics.isNotEmpty
              ? '${_availableBiometrics.map((type) => AuthService.getBiometricTypeDisplayName(type)).join(', ')}으로 인증해주세요'
              : '생체인증으로 인증해주세요',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: _isLoading ? null : _authenticateWithBiometric,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blue,
                width: 3,
              ),
              color: Colors.blue.withOpacity(0.1),
            ),
            child: Icon(
              _availableBiometrics.contains(BiometricType.face)
                  ? Icons.face
                  : Icons.fingerprint,
              size: 60,
              color: Colors.blue,
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_isLoading) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
        ],
        TextButton(
          onPressed: _isLoading ? null : _authenticateWithBiometric,
          child: const Text(
            '다시 시도',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
} 