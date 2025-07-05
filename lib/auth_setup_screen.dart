import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_service.dart';
import 'main.dart';

/// 최초 인증 설정 화면
/// PIN 설정 및 인증 방법 선택을 진행합니다.
class AuthSetupScreen extends StatefulWidget {
  const AuthSetupScreen({Key? key}) : super(key: key);

  @override
  State<AuthSetupScreen> createState() => _AuthSetupScreenState();
}

class _AuthSetupScreenState extends State<AuthSetupScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _pinController = TextEditingController();
  int _currentPage = 0;
  String _pin = '';
  String _confirmPin = '';
  bool _biometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];
  AuthMethod _selectedAuthMethod = AuthMethod.pin;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  /// 생체인증 사용 가능 여부 확인
  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await AuthService.isBiometricAvailable();
    final availableBiometrics = await AuthService.getAvailableBiometrics();
    
    setState(() {
      _biometricAvailable = isAvailable && availableBiometrics.isNotEmpty;
      _availableBiometrics = availableBiometrics;
    });
  }

  /// 다음 페이지로 이동
  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 이전 페이지로 이동
  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// PIN 설정 완료
  Future<void> _completeSetup() async {
    try {
      // PIN 저장
      await AuthService.savePin(_pin);
      
      // 인증 방법 설정
      await AuthService.setAuthMethod(_selectedAuthMethod);
      
      // 생체인증 활성화 설정
      if (_selectedAuthMethod == AuthMethod.biometric) {
        await AuthService.setBiometricEnabled(true);
      }

      // 최초 설정 완료 표시
      await DataService.setNotFirstLaunch();
      
      // 세션 PIN 설정 (메모 저장을 위해 필요)
      DataService.setSessionPin(_pin);
      
      // 메인 화면으로 이동
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('설정 저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보안 설정'),
        automaticallyImplyLeading: false,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [
          _buildWelcomePage(),
          _buildPinSetupPage(),
          _buildAuthMethodSelectionPage(),
        ],
      ),
    );
  }

  /// 환영 페이지
  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.security,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 32),
          const Text(
            '보안 메모장에 오신 것을 환영합니다!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            '소중한 메모를 안전하게 보호하기 위해\n보안 설정을 진행하겠습니다.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '시작하기',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// PIN 설정 페이지
  Widget _buildPinSetupPage() {
    final isConfirmMode = _pin.isNotEmpty;
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock,
            size: 60,
            color: Colors.blue,
          ),
          const SizedBox(height: 32),
          Text(
            isConfirmMode ? 'PIN 번호를 다시 입력해주세요' : 'PIN 번호를 설정해주세요',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            isConfirmMode 
                ? '확인을 위해 동일한 PIN을 입력해주세요'
                : '4자리 숫자로 PIN을 설정해주세요',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Pinput(
            key: ValueKey(isConfirmMode ? 'confirm' : 'initial'),
            controller: _pinController,
            length: 4,
            obscureText: true,
            autofocus: true,
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
            onCompleted: (pin) {
              if (isConfirmMode) {
                if (pin == _pin) {
                  _confirmPin = pin;
                  _nextPage();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN이 일치하지 않습니다. 다시 입력해주세요.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  setState(() {
                    _pin = '';
                    _confirmPin = '';
                  });
                  _pinController.clear();
                }
              } else {
                setState(() {
                  _pin = pin;
                });
                _pinController.clear();
                // 잠시 후 화면 업데이트를 위해 약간의 지연
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    setState(() {});
                  }
                });
              }
            },
          ),
          const SizedBox(height: 48),
          if (_currentPage > 0)
            TextButton(
              onPressed: _previousPage,
              child: const Text('이전'),
            ),
        ],
      ),
    );
  }

  /// 인증 방법 선택 페이지
  Widget _buildAuthMethodSelectionPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.fingerprint,
            size: 60,
            color: Colors.blue,
          ),
          const SizedBox(height: 32),
          const Text(
            '인증 방법을 선택해주세요',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            '앱을 실행할 때 사용할 인증 방법을 선택하세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          
          // PIN 인증 옵션
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock, color: Colors.blue),
              title: const Text('PIN 번호'),
              subtitle: const Text('4자리 숫자로 인증합니다'),
              trailing: Radio<AuthMethod>(
                value: AuthMethod.pin,
                groupValue: _selectedAuthMethod,
                onChanged: (value) {
                  setState(() {
                    _selectedAuthMethod = value!;
                  });
                },
              ),
              onTap: () {
                setState(() {
                  _selectedAuthMethod = AuthMethod.pin;
                });
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 생체인증 옵션
          Card(
            child: ListTile(
              leading: Icon(
                Icons.fingerprint,
                color: _biometricAvailable ? Colors.blue : Colors.grey,
              ),
              title: Text(
                _availableBiometrics.isNotEmpty
                    ? _availableBiometrics.map((type) => 
                        AuthService.getBiometricTypeDisplayName(type)).join(', ')
                    : '생체인증',
              ),
              subtitle: Text(
                _biometricAvailable 
                    ? '생체인증으로 빠르고 안전하게 인증합니다'
                    : '이 기기에서는 생체인증을 사용할 수 없습니다',
              ),
              trailing: Radio<AuthMethod>(
                value: AuthMethod.biometric,
                groupValue: _selectedAuthMethod,
                onChanged: _biometricAvailable ? (value) {
                  setState(() {
                    _selectedAuthMethod = value!;
                  });
                } : null,
              ),
              onTap: _biometricAvailable ? () {
                setState(() {
                  _selectedAuthMethod = AuthMethod.biometric;
                });
              } : null,
              enabled: _biometricAvailable,
            ),
          ),
          
          const SizedBox(height: 48),
          
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _previousPage,
                  child: const Text('이전'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _completeSetup,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '설정 완료',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pinController.dispose();
    super.dispose();
  }
} 