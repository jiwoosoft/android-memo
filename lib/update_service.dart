import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// GitHub API를 통해 앱 업데이트 정보를 확인하는 서비스
class UpdateService {
  // GitHub 저장소 정보
  static const String _owner = 'jiwoosoft';
  static const String _repo = 'secure-memo';
  static const String _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  static Future<UpdateCheckResult> checkForUpdate() async {
    try {
      // 현재 앱 버전 정보 가져오기
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // GitHub API 호출
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'].toString().replaceAll('v', '');
        
        // 다운로드 URL 찾기
        String? downloadUrl;
        final assets = data['assets'] as List;
        for (var asset in assets) {
          if (asset['name'].toString().endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'];
            break;
          }
        }

        // Google Drive 링크가 있는지 확인
        final body = data['body'] as String;
        final driveUrlMatch = RegExp(r'https://drive\.google\.com/[^\s\)]+').firstMatch(body);
        if (driveUrlMatch != null) {
          downloadUrl = driveUrlMatch.group(0);
        }

        final hasUpdate = _compareVersions(currentVersion, latestVersion) < 0;
        
        return UpdateCheckResult(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          hasUpdate: hasUpdate,
          releaseInfo: hasUpdate ? ReleaseInfo(
            version: latestVersion,
            body: data['body'],
            downloadUrl: downloadUrl,
          ) : null,
        );
      } else {
        throw Exception('GitHub API 호출 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('업데이트 확인 오류: $e');
      rethrow;
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
  final ReleaseInfo? releaseInfo;

  UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    this.releaseInfo,
  });
}

class ReleaseInfo {
  final String version;
  final String body;
  final String? downloadUrl;

  ReleaseInfo({
    required this.version,
    required this.body,
    this.downloadUrl,
  });
} 