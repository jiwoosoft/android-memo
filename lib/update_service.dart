import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// GitHub API를 통해 앱 업데이트 정보를 확인하는 서비스
class UpdateService {
  // GitHub 저장소 정보
  static const String _owner = 'jiwoosoft';
  static const String _repo = 'android-memo';
  static const String _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';
  
  // 기본 다운로드 URL (최신 APK가 있는 Google Drive 링크)
  static const String _defaultDownloadUrl = 'https://drive.google.com/file/d/1p2_AzvgqgYLH2PKm1s8jHhRY4QXyfPLQ/view?usp=drivesdk';

  static Future<UpdateCheckResult> checkForUpdate() async {
    try {
      // 현재 앱 버전 정보 가져오기
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      print('현재 버전: $currentVersion');
      print('GitHub API 호출 중...');

      // GitHub API 호출
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'SecureMemoApp/1.0',
        },
      ).timeout(Duration(seconds: 10));

      print('GitHub API 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String latestVersion = data['tag_name'].toString().replaceAll('v', '');
        
        print('최신 버전: $latestVersion');
        
        // 다운로드 URL 찾기 (GitHub 릴리즈 또는 Google Drive)
        String downloadUrl = _defaultDownloadUrl;  // 기본값 설정
        
        // 1. GitHub 릴리즈 에셋에서 APK 찾기
        if (data['assets'] != null && data['assets'] is List) {
          final assets = data['assets'] as List;
          for (var asset in assets) {
            if (asset['name'].toString().endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'];
              break;
            }
          }
        }
        
        // 2. 릴리즈 노트에서 Google Drive 링크 찾기
        final body = data['body'] as String? ?? '';
        final driveUrlMatch = RegExp(r'https://drive\.google\.com/file/d/[a-zA-Z0-9_-]+/[^\s\)]+').firstMatch(body);
        if (driveUrlMatch != null) {
          downloadUrl = driveUrlMatch.group(0)!;
        }

        // 강제 업데이트 체크: 현재 버전이 2.0.2보다 낮으면 무조건 업데이트 필요
        const String minimumVersion = '2.0.2';
        bool hasUpdate = _compareVersions(currentVersion, latestVersion) < 0;
        
        // 현재 버전이 2.0.2보다 낮으면 강제 업데이트
        if (_compareVersions(currentVersion, minimumVersion) < 0) {
          hasUpdate = true;
          latestVersion = minimumVersion;
          downloadUrl = _defaultDownloadUrl;
          
          print('강제 업데이트 필요: $currentVersion < $minimumVersion');
          return UpdateCheckResult(
            currentVersion: currentVersion,
            latestVersion: minimumVersion,
            hasUpdate: true,
            releaseInfo: ReleaseInfo(
              version: minimumVersion,
              body: '🔐 MAJOR 업데이트 - 지문인증 시스템 추가!\n\n주요 변경사항:\n- 🔒 지문인증 시스템 추가 (PIN + 생체인증)\n- ⚙️ 인증 방법 설정 (PIN ↔ 지문인증 전환)\n- 🔄 자동 생체인증 (앱 시작 시)\n- 🛡️ 보안 강화 (Flutter Secure Storage)\n- 🎨 새로운 인증 UI\n\n⚠️ Major 업데이트로 새로설치 권장',
              downloadUrl: _defaultDownloadUrl,
            ),
          );
        }
        
        print('업데이트 필요: $hasUpdate');
        print('다운로드 URL: $downloadUrl');
        
        return UpdateCheckResult(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          hasUpdate: hasUpdate,
          releaseInfo: ReleaseInfo(
            version: latestVersion,
            body: data['body'] ?? '업데이트 정보가 없습니다.',
            downloadUrl: downloadUrl,
          ),
        );
      }
      
      print('GitHub API 오류: ${response.statusCode}');
      print('응답 내용: ${response.body}');
      // API 호출 실패 시 기본 다운로드 URL 사용
      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: '2.0.2',  // v2.0+ 지문인증 시스템 업데이트 (업데이트 서비스 수정)
        hasUpdate: true,  // 강제 업데이트 표시
        releaseInfo: ReleaseInfo(
          version: '2.0.2',  // v2.0+ 지문인증 시스템 업데이트 (업데이트 서비스 수정)
          body: '🔐 MAJOR 업데이트 - 지문인증 시스템 추가!\n\n주요 변경사항:\n- 🔒 지문인증 시스템 추가 (PIN + 생체인증)\n- ⚙️ 인증 방법 설정 (PIN ↔ 지문인증 전환)\n- 🔄 자동 생체인증 (앱 시작 시)\n- 🛡️ 보안 강화 (Flutter Secure Storage)\n- 🎨 새로운 인증 UI\n\n⚠️ Major 업데이트로 새로설치 권장',
          downloadUrl: _defaultDownloadUrl,
        ),
      );
    } catch (e) {
      print('업데이트 확인 오류: $e');
      final packageInfo = await PackageInfo.fromPlatform();
      return UpdateCheckResult(
        currentVersion: packageInfo.version,
        latestVersion: '2.0.2',  // v2.0+ 지문인증 시스템 업데이트 (업데이트 서비스 수정)
        hasUpdate: true,  // 강제 업데이트 표시
        releaseInfo: ReleaseInfo(
          version: '2.0.2',
          body: '🔐 MAJOR 업데이트 - 지문인증 시스템 추가!\n\n주요 변경사항:\n- 🔒 지문인증 시스템 추가 (PIN + 생체인증)\n- ⚙️ 인증 방법 설정 (PIN ↔ 지문인증 전환)\n- 🔄 자동 생체인증 (앱 시작 시)\n- 🛡️ 보안 강화 (Flutter Secure Storage)\n- 🎨 새로운 인증 UI\n\n⚠️ Major 업데이트로 새로설치 권장',
          downloadUrl: _defaultDownloadUrl,
        ),
      );
    }
  }

  // 버전 비교 함수
  static int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.');
    final v2Parts = v2.split('.');
    
    for (var i = 0; i < 3; i++) {
      final v1Part = int.tryParse(v1Parts[i]) ?? 0;
      final v2Part = int.tryParse(v2Parts[i]) ?? 0;
      
      if (v1Part < v2Part) return -1;
      if (v1Part > v2Part) return 1;
    }
    
    return 0;
  }
}

class UpdateCheckResult {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final ReleaseInfo releaseInfo;

  UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.releaseInfo,
  });
}

class ReleaseInfo {
  final String version;
  final String body;
  final String downloadUrl;

  ReleaseInfo({
    required this.version,
    required this.body,
    required this.downloadUrl,
  });
} 