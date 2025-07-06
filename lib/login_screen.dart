import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_service.dart';
import 'main.dart';
import 'package:flutter/services.dart'; // Added for PlatformException

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
  String _biometricStatusMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  /// 인증 시스템 초기화
  Future<void> _initializeAuth() async {
    try {
      print('🔐 [INIT] ===== 인증 시스템 초기화 시작 =====');
      
      // 생체인증 사용 가능 여부 확인
      final biometricAvailable = await AuthService.isBiometricAvailable();
      final biometricEnabled = await AuthService.isBiometricEnabled();
      final currentAuthMethod = await AuthService.getAuthMethod();
      final availableBiometrics = await AuthService.getAvailableBiometrics();
      
      print('🔐 [INIT] 생체인증 사용 가능: $biometricAvailable');
      print('🔐 [INIT] 생체인증 활성화: $biometricEnabled');
      print('🔐 [INIT] 현재 인증 방법: $currentAuthMethod');
      print('🔐 [INIT] 사용 가능한 생체인증: ${availableBiometrics.map((e) => AuthService.getBiometricTypeDisplayName(e)).join(', ')}');

      // 생체인증 상태 메시지 생성
      String statusMessage = '';
      if (!biometricAvailable) {
        statusMessage = '이 기기에서는 생체인증을 사용할 수 없습니다.';
      } else if (availableBiometrics.isEmpty) {
        statusMessage = '등록된 생체인증이 없습니다. 기기 설정에서 지문을 등록해주세요.';
      } else if (!biometricEnabled) {
        statusMessage = '생체인증이 비활성화되어 있습니다.';
      } else {
        statusMessage = '생체인증이 준비되었습니다.';
      }
      
      setState(() {
        _biometricAvailable = biometricAvailable;
        _biometricEnabled = biometricEnabled;
        _currentAuthMethod = currentAuthMethod;
        _availableBiometrics = availableBiometrics;
        _biometricStatusMessage = statusMessage;
      });

      // 지문인증이 설정되어 있다면 UI를 지문인증 모드로 변경 (자동 실행 제거)
      if (currentAuthMethod == AuthMethod.biometric && biometricEnabled && biometricAvailable) {
        print('🔐 [INIT] 지문인증 모드로 설정됨 (자동 실행하지 않음)');
      }
      
      print('🔐 [INIT] ===== 인증 시스템 초기화 완료 =====');
    } catch (e) {
      print('❌ [INIT] 인증 시스템 초기화 오류: $e');
      setState(() {
        _biometricStatusMessage = '인증 시스템 초기화 중 오류가 발생했습니다: $e';
      });
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

  /// 지문인증으로 로그인 시도
  Future<void> _loginWithBiometric() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    print('👆 [LOGIN] ===== 지문인증 로그인 시작 =====');

    try {
      print('🔍 [LOGIN] 지문인증 실행...');
      final authenticated = await AuthService.authenticateWithBiometric();
      
      if (authenticated) {
        print('✅ [LOGIN] 지문인증 성공!');
        _showSuccessMessage('🎉 지문인증 성공!');
        
        // 저장된 PIN을 가져와서 세션 설정
        final savedPin = await AuthService.getSavedPin();
        if (savedPin != null) {
          await _navigateToMainApp(savedPin);
        } else {
          print('❌ [LOGIN] 저장된 PIN을 찾을 수 없음');
          _showErrorMessage('저장된 PIN을 찾을 수 없습니다. 앱을 재설치해주세요.');
        }
      } else {
        print('❌ [LOGIN] 지문인증 실패');
        
        // 지문인증 실패 시 자동으로 PIN 모드로 전환
        await _showBiometricFailureDialog();
      }
    } catch (e) {
      print('❌ [LOGIN] 지문인증 오류: $e');
      
      // 오류 발생 시에도 PIN 모드 전환 옵션 제공
      await _showBiometricFailureDialog();
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('👆 [LOGIN] ===== 지문인증 로그인 종료 =====');
    }
  }

  /// 지문인증 실패 시 PIN 모드 전환 다이얼로그
  Future<void> _showBiometricFailureDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('👆 지문인증 실패', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '지문인증에 실패했습니다.',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Text(
              '다음 중 선택하세요:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '• PIN으로 로그인\n• 지문인증 다시 시도\n• 지문인증 완전히 비활성화',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'retry'),
            child: Text('다시 시도', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'disable'),
            child: Text('지문인증 끄기', style: TextStyle(color: Colors.orange)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'pin'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: Text('PIN 로그인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == 'pin') {
      // PIN 모드로 전환
      setState(() {
        _currentAuthMethod = AuthMethod.pin;
      });
      print('🔄 [LOGIN] 지문인증 실패로 PIN 모드 전환');
    } else if (result == 'disable') {
      // 지문인증 완전히 비활성화
      await _disableBiometricAndSwitchToPin();
    } else if (result == 'retry') {
      // 다시 시도
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) _loginWithBiometric();
      });
    }
  }

  /// 지문인증 비활성화하고 PIN 모드로 전환
  Future<void> _disableBiometricAndSwitchToPin() async {
    try {
      print('🔧 [LOGIN] 지문인증 비활성화 중...');
      await AuthService.setAuthMethod(AuthMethod.pin);
      await AuthService.setBiometricEnabled(false);
      
      setState(() {
        _currentAuthMethod = AuthMethod.pin;
        _biometricEnabled = false;
      });
      
      _showSuccessMessage('✅ 지문인증이 비활성화되었습니다. 이제 PIN으로만 로그인할 수 있습니다.');
      print('✅ [LOGIN] 지문인증 비활성화 완료');
    } catch (e) {
      print('❌ [LOGIN] 지문인증 비활성화 오류: $e');
      _showErrorMessage('지문인증 비활성화 중 오류가 발생했습니다: $e');
    }
  }

  /// 지문인증 실패 시 상세한 오류 메시지 표시
  void _showDetailedBiometricError() {
    _showErrorMessage(
      '👆 지문인증 실패\n\n'
      '지문인증에 실패했습니다.\n\n'
      '📋 단계별 해결 방법:\n\n'
      '1️⃣ 지문 센서 청소\n'
      '   • 부드러운 천으로 센서를 깨끗이 닦기\n'
      '   • 알코올 솜으로 센서 소독\n\n'
      '2️⃣ 손가락 상태 확인\n'
      '   • 손가락을 깨끗이 닦기\n'
      '   • 크림이나 물기 완전히 제거\n'
      '   • 상처나 밴드 없는 손가락 사용\n\n'
      '3️⃣ 인증 방법 개선\n'
      '   • 센서에 천천히 지문 대기 (2-3초)\n'
      '   • 너무 세게 누르지 말기\n'
      '   • 등록된 다른 손가락으로 시도\n\n'
      '4️⃣ 기기 설정 확인\n'
      '   • 설정 → 보안 → 지문 → 새 지문 추가\n'
      '   • 같은 손가락을 여러 각도로 등록\n'
      '   • 기기 재시작 후 재시도\n\n'
      '5️⃣ 임시 해결책\n'
      '   • PIN으로 로그인 후 지문 재설정\n'
      '   • 앱 재시작 후 다시 시도\n\n'
      '⚠️ 문제가 계속되면 기기의 지문인식\n'
      '기능 자체에 문제가 있을 수 있습니다.'
    );
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
    print('🔄 [SWITCH] 인증 방법 전환: $_currentAuthMethod');
  }

  /// 오류 메시지 표시
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// 성공 메시지 표시
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
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
                  border: Border.all(
                    color: _biometricAvailable && _availableBiometrics.isNotEmpty 
                        ? Colors.teal 
                        : Colors.grey, 
                    width: 2
                  ),
                  color: Colors.grey[850],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(60),
                  onTap: (_isLoading || !_biometricAvailable || _availableBiometrics.isEmpty) 
                      ? null 
                      : _loginWithBiometric,
                  child: Icon(
                    Icons.fingerprint,
                    size: 60,
                    color: _isLoading 
                        ? Colors.grey 
                        : (_biometricAvailable && _availableBiometrics.isNotEmpty 
                            ? Colors.teal 
                            : Colors.grey),
                  ),
                ),
              ),
              SizedBox(height: 24),
              
              // 지문인증 상태 메시지
              if (_biometricStatusMessage.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _biometricAvailable && _availableBiometrics.isNotEmpty 
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _biometricAvailable && _availableBiometrics.isNotEmpty 
                          ? Colors.green 
                          : Colors.orange,
                    ),
                  ),
                  child: Text(
                    _biometricStatusMessage,
                    style: TextStyle(
                      color: _biometricAvailable && _availableBiometrics.isNotEmpty 
                          ? Colors.green 
                          : Colors.orange,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 16),
              ],
              
              // 지문인증 버튼
              if (!_isLoading && _biometricAvailable && _availableBiometrics.isNotEmpty)
                ElevatedButton(
                  onPressed: _loginWithBiometric,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text('지문인증 시작'),
                ),
              
              SizedBox(height: 16),
              
              // PIN으로 로그인 버튼 (항상 표시)
              OutlinedButton(
                onPressed: _isLoading ? null : () {
                  setState(() {
                    _currentAuthMethod = AuthMethod.pin;
                  });
                  print('🔄 [LOGIN] 사용자가 PIN 모드로 전환');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white70),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text('PIN으로 로그인'),
              ),
              
              SizedBox(height: 16),
              
              // 지문인증 포기 버튼
              TextButton(
                onPressed: _isLoading ? null : () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.grey[850],
                      title: Text('지문인증 비활성화', style: TextStyle(color: Colors.white)),
                      content: Text(
                        '지문인증을 완전히 비활성화하시겠습니까?\n\n이후 PIN으로만 로그인할 수 있습니다.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('취소', style: TextStyle(color: Colors.grey)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          child: Text('비활성화', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    await _disableBiometricAndSwitchToPin();
                  }
                },
                child: Text(
                  '지문인증 완전히 끄기',
                  style: TextStyle(color: Colors.orange),
                ),
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

 