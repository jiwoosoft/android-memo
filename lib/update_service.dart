import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// GitHub API를 통해 앱 업데이트 정보를 확인하는 서비스
class UpdateService {
  // GitHub 저장소 정보
  static const String _owner = 'jiwoosoft';
  static const String _repo = 'android-memo';
  static const String _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';
  
  // 최신 APK 다운로드 URL (v2.1.2)
  static const String _defaultDownloadUrl = 'https://drive.google.com/file/d/1CIcBoNOQn_rL9DtpXxkeIjpvd8oM2rEL/view?usp=drivesdk';

  static Future<UpdateCheckResult> checkForUpdate() async {
    try {
      // 현재 앱 버전 정보 가져오기
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      print('🔍 [UPDATE] 현재 버전: $currentVersion');
      print('🌐 [UPDATE] GitHub API 호출 중...');

      // GitHub API 호출
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'SecureMemoApp/2.1',
        },
      ).timeout(Duration(seconds: 15));

      print('📡 [UPDATE] GitHub API 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String latestVersion = data['tag_name'].toString().replaceAll('v', '');
        
        print('🆕 [UPDATE] GitHub 최신 버전: $latestVersion');
        
        // 다운로드 URL 찾기 (GitHub 릴리즈 또는 Google Drive)
        String downloadUrl = _defaultDownloadUrl;  // 기본값: v2.1.2
        
        // 1. GitHub 릴리즈 에셋에서 APK 찾기
        if (data['assets'] != null && data['assets'] is List) {
          final assets = data['assets'] as List;
          for (var asset in assets) {
            if (asset['name'].toString().endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'];
              print('📦 [UPDATE] GitHub APK 발견: ${asset['name']}');
              break;
            }
          }
        }
        
        // 2. 릴리즈 노트에서 Google Drive 링크 찾기
        final body = data['body'] as String? ?? '';
        final driveUrlMatch = RegExp(r'https://drive\.google\.com/file/d/[a-zA-Z0-9_-]+/[^\s\)]+').firstMatch(body);
        if (driveUrlMatch != null) {
          downloadUrl = driveUrlMatch.group(0)!;
          print('🔗 [UPDATE] Google Drive 링크 발견');
        }

        // 버전 비교
        bool hasUpdate = _compareVersions(currentVersion, latestVersion) < 0;
        
        print('📊 [UPDATE] 버전 비교: $currentVersion vs $latestVersion');
        print('🔄 [UPDATE] 업데이트 필요: $hasUpdate');
        print('🔗 [UPDATE] 다운로드 URL: $downloadUrl');
        
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
      
      print('❌ [UPDATE] GitHub API 오류: ${response.statusCode}');
      print('📄 [UPDATE] 응답 내용: ${response.body}');
      
      // API 호출 실패 시 최신 버전으로 강제 업데이트 안내
      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: '2.1.2',  // 현재 최신 버전
        hasUpdate: _compareVersions(currentVersion, '2.1.2') < 0,
        releaseInfo: ReleaseInfo(
          version: '2.1.2',
          body: '🔐 지문인증 시스템 완전 개선!\n\n주요 변경사항:\n- 👆 지문인증 실패 문제 완전 해결\n- 🔧 인증 옵션 최적화 (호환성 향상)\n- 📊 상세한 오류 진단 (13가지 케이스)\n- 💬 구체적인 해결 방법 안내\n- 🎯 더 많은 Android 기기 지원\n\n✨ 이제 지문인증이 안정적으로 작동합니다!',
          downloadUrl: _defaultDownloadUrl,
        ),
      );
    } catch (e) {
      print('❌ [UPDATE] 업데이트 확인 오류: $e');
      final packageInfo = await PackageInfo.fromPlatform();
      
      // 오류 발생 시에도 최신 버전 정보 제공
      return UpdateCheckResult(
        currentVersion: packageInfo.version,
        latestVersion: '2.1.2',  // 현재 최신 버전
        hasUpdate: _compareVersions(packageInfo.version, '2.1.2') < 0,
        releaseInfo: ReleaseInfo(
          version: '2.1.2',
          body: '🔐 지문인증 시스템 완전 개선!\n\n주요 변경사항:\n- 👆 지문인증 실패 문제 완전 해결\n- 🔧 인증 옵션 최적화 (호환성 향상)\n- 📊 상세한 오류 진단 (13가지 케이스)\n- 💬 구체적인 해결 방법 안내\n- 🎯 더 많은 Android 기기 지원\n\n✨ 이제 지문인증이 안정적으로 작동합니다!\n\n⚠️ 네트워크 오류로 인해 수동 업데이트가 필요할 수 있습니다.',
          downloadUrl: _defaultDownloadUrl,
        ),
      );
    }
  }

  // 버전 비교 함수 (개선된 버전)
  static int _compareVersions(String v1, String v2) {
    print('🔍 [VERSION] 버전 비교: "$v1" vs "$v2"');
    
    // 버전 문자열 정규화 (v 접두사 제거)
    v1 = v1.replaceAll('v', '');
    v2 = v2.replaceAll('v', '');
    
    final v1Parts = v1.split('.');
    final v2Parts = v2.split('.');
    
    // 최대 3개 부분까지 비교 (major.minor.patch)
    final maxLength = 3;
    
    for (var i = 0; i < maxLength; i++) {
      final v1Part = i < v1Parts.length ? (int.tryParse(v1Parts[i]) ?? 0) : 0;
      final v2Part = i < v2Parts.length ? (int.tryParse(v2Parts[i]) ?? 0) : 0;
      
      print('🔢 [VERSION] 부분 $i: $v1Part vs $v2Part');
      
      if (v1Part < v2Part) {
        print('📉 [VERSION] $v1 < $v2');
        return -1;
      }
      if (v1Part > v2Part) {
        print('📈 [VERSION] $v1 > $v2');
        return 1;
      }
    }
    
    print('⚖️ [VERSION] $v1 == $v2');
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