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
  static const String _defaultDownloadUrl = 'https://drive.google.com/file/d/1acuvBJCRUBWDJaxRA97aT8rx_AB_mKFY/view?usp=drivesdk';

  static Future<UpdateCheckResult> checkForUpdate() async {
    try {
      // 현재 앱 버전 정보 가져오기
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // GitHub API 호출
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'SecureMemoApp/1.0',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'].toString().replaceAll('v', '');
        
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

        final hasUpdate = _compareVersions(currentVersion, latestVersion) < 0;
        
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
      // API 호출 실패 시 기본 다운로드 URL 사용
      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: '1.0.19',  // 최신 버전으로 업데이트
        hasUpdate: true,  // 강제 업데이트 표시
        releaseInfo: ReleaseInfo(
          version: '1.0.19',  // 최신 버전으로 업데이트
          body: '최신 버전으로 업데이트해 주세요.',
          downloadUrl: _defaultDownloadUrl,
        ),
      );
    } catch (e) {
      print('업데이트 확인 오류: $e');
      final packageInfo = await PackageInfo.fromPlatform();
      return UpdateCheckResult(
        currentVersion: packageInfo.version,
        latestVersion: packageInfo.version,
        hasUpdate: true,  // 강제 업데이트 표시
        releaseInfo: ReleaseInfo(
          version: '1.0.14',
          body: '최신 버전으로 업데이트해 주세요.',
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