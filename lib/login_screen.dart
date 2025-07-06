import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_service.dart';

/// PIN 전용 로그인 화면
/// 지문인증 기능을 제거하고 PIN 입력만 지원합니다.
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('🔐 [LOGIN] PIN 전용 로그인 화면 초기화');
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  /// PIN 로그인 실행
  Future<void> _loginWithPin() async {
    final pin = _pinController.text.trim();
    
    if (pin.isEmpty) {
      setState(() {
        _errorMessage = 'PIN을 입력해주세요.';
      });
      return;
    }

    if (pin.length < 4) {
      setState(() {
        _errorMessage = 'PIN은 최소 4자리 이상이어야 합니다.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔐 [LOGIN] PIN 인증 시도: 길이=${pin.length}');
      
      final success = await AuthService.authenticate(pin: pin);
      
      if (success) {
        print('✅ [LOGIN] PIN 인증 성공');
        
        // 성공 피드백
        HapticFeedback.lightImpact();
        
        // 메인 화면으로 이동
        Navigator.of(context).pushReplacementNamed('/main');
      } else {
        print('❌ [LOGIN] PIN 인증 실패');
        
        // 실패 피드백
        HapticFeedback.heavyImpact();
        
        setState(() {
          _errorMessage = 'PIN이 올바르지 않습니다. 다시 시도해주세요.';
        });
        
        // PIN 입력 필드 초기화
        _pinController.clear();
      }
    } catch (e) {
      print('❌ [LOGIN] PIN 인증 중 오류: $e');
      
      setState(() {
        _errorMessage = '인증 중 오류가 발생했습니다. 다시 시도해주세요.';
      });
      
      _pinController.clear();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 오류 메시지 초기화
  void _clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 앱 로고
              Container(
                margin: const EdgeInsets.only(bottom: 48),
                child: Column(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 80,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '보안 메모',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PIN으로 안전하게 보호되는 메모',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // PIN 입력 섹션
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 제목
                    Text(
                      'PIN 입력',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // PIN 입력 필드
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        letterSpacing: 4,
                      ),
                      decoration: InputDecoration(
                        hintText: 'PIN을 입력하세요',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (value) => _clearError(),
                      onSubmitted: (value) => _loginWithPin(),
                    ),

                    const SizedBox(height: 24),

                    // 로그인 버튼
                    ElevatedButton(
                      onPressed: _isLoading ? null : _loginWithPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'PIN으로 로그인',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),

                    // 오류 메시지
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 도움말 텍스트
              Text(
                'PIN을 잊으셨나요?\n앱을 재설치하면 새로운 PIN을 설정할 수 있습니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

 