import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_service.dart';
import 'main.dart'; // DataService를 위해 추가

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
      print('🔐 [LOGIN] PIN 인증 시도: 길이=${pin.length}, 내용=${pin.replaceAll(RegExp(r'.'), '*')}');
      
      // PIN 설정 여부 확인
      final isPinSet = await AuthService.isPinSet();
      print('🔐 [LOGIN] PIN 설정 여부: $isPinSet');
      
      if (!isPinSet) {
        throw Exception('PIN이 설정되지 않았습니다. 설정 화면으로 이동하세요.');
      }
      
      final success = await AuthService.authenticate(pin: pin);
      
      if (success) {
        print('✅ [LOGIN] PIN 인증 성공');
        
        // 세션 PIN 설정 (메모 데이터 복호화를 위해 필요)
        DataService.setSessionPin(pin);
        print('🔐 [LOGIN] 세션 PIN 설정 완료');
        
        // 세션 PIN 설정 확인
        final verifySessionPin = await DataService.getCurrentSessionPin();
        print('🔐 [LOGIN] 세션 PIN 확인: ${verifySessionPin != null ? '설정됨' : '설정 실패'}');
        
        // 성공 피드백
        HapticFeedback.lightImpact();
        
        // 약간의 지연을 두고 메인 화면으로 이동 (세션 PIN 안정화)
        print('🔐 [LOGIN] 메인 화면으로 이동 준비 중...');
        await Future.delayed(Duration(milliseconds: 300));
        
        // 메인 화면으로 이동
        print('🔐 [LOGIN] 메인 화면으로 이동');
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
      backgroundColor: Colors.black,
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
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '안전한 메모장',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PIN으로 안전하게 보호되는 메모',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // PIN 입력 섹션
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[700]!, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
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
                        color: Colors.white,
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
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'PIN을 입력하세요',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        counterText: '',
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[600]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[600]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal, width: 2),
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
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[700],
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
                          color: Colors.red[900]?.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[700]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[400],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red[300],
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
                  color: Colors.grey[400],
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

 