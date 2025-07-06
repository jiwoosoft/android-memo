import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'main.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;

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
        print('🔐 [LOGIN] ✅ 로그인 성공! 메모 앱으로 이동');
        // 세션 PIN 설정
        DataService.setSessionPin(pin);
        // 기존 MemoListScreen으로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MemoListScreen()),
        );
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
        title: Text('🔒 PIN 로그인', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[850],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security,
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
              'PIN 번호를 입력해주세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 48),
            
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
            
            if (_isLoading) ...[
              CircularProgressIndicator(color: Colors.teal),
              SizedBox(height: 16),
              Text(
                '로그인 중...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
            
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
        ),
      ),
    );
  }
}

 