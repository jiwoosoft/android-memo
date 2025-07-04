import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// GitHub API를 통해 앱 업데이트 정보를 확인하는 서비스
class UpdateService {
  // GitHub 저장소 정보
  static const String _owner = 'jiwoosoft';
  static const String _repo = 'android-memo';
  static const String _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// 최신 릴리즈 정보를 가져오는 메서드
  static Future<ReleaseInfo?> getLatestRelease() async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'SecureMemoApp/1.0',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ReleaseInfo.fromJson(data);
      } else {
        print('GitHub API 오류: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('네트워크 오류: $e');
      return null;
    }
  }

  /// 현재 앱 버전과 최신 버전을 비교하여 업데이트 필요 여부 확인
  static Future<UpdateCheckResult> checkForUpdate() async {
    try {
      // 현재 앱 정보 가져오기
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 최신 릴리즈 정보 가져오기
      final latestRelease = await getLatestRelease();
      
      if (latestRelease == null) {
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          errorMessage: '업데이트 정보를 가져올 수 없습니다.',
        );
      }

      // 버전 비교 로직
      final isUpdateAvailable = _compareVersions(
        currentVersion, 
        currentBuildNumber,
        latestRelease.tagName,
        latestRelease.buildNumber ?? 0,
      );

      return UpdateCheckResult(
        hasUpdate: isUpdateAvailable,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        latestVersion: latestRelease.tagName,
        latestBuildNumber: latestRelease.buildNumber,
        releaseInfo: latestRelease,
      );
    } catch (e) {
      print('업데이트 확인 오류: $e');
      final packageInfo = await PackageInfo.fromPlatform();
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: packageInfo.version,
        currentBuildNumber: int.tryParse(packageInfo.buildNumber) ?? 0,
        errorMessage: '업데이트 확인 중 오류가 발생했습니다.',
      );
    }
  }

  /// 버전 비교 메서드
  static bool _compareVersions(String currentVersion, int currentBuild, String latestVersion, int latestBuild) {
    try {
      // 태그에서 'v' 접두사 제거
      final cleanCurrentVersion = currentVersion.replaceAll('v', '');
      final cleanLatestVersion = latestVersion.replaceAll('v', '');

      // 버전 문자열을 숫자 배열로 변환
      final currentParts = cleanCurrentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestParts = cleanLatestVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      // 길이를 맞춤 (예: 1.0 vs 1.0.0)
      while (currentParts.length < 3) currentParts.add(0);
      while (latestParts.length < 3) latestParts.add(0);

      // 버전 비교
      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) {
          return true; // 최신 버전이 더 높음
        } else if (latestParts[i] < currentParts[i]) {
          return false; // 현재 버전이 더 높음
        }
      }

      // 메이저, 마이너, 패치 버전이 같으면 빌드 번호 비교
      return latestBuild > currentBuild;
    } catch (e) {
      print('버전 비교 오류: $e');
      return false;
    }
  }
}

/// 릴리즈 정보를 담는 클래스
class ReleaseInfo {
  final String name;
  final String tagName;
  final String body;
  final String htmlUrl;
  final DateTime publishedAt;
  final String? downloadUrl;
  final int? buildNumber;

  ReleaseInfo({
    required this.name,
    required this.tagName,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    this.downloadUrl,
    this.buildNumber,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    // Google Drive 다운로드 URL 찾기 (릴리즈 노트에서 추출)
    String? apkUrl;
    final body = json['body'] ?? '';
    
    // 릴리즈 노트에서 Google Drive 링크 추출 (여러 패턴 시도)
    final googleDrivePatterns = [
      RegExp(r'https://drive\.google\.com/file/d/([a-zA-Z0-9_-]+)/[^)\s]*'),
      RegExp(r'https://drive\.google\.com/file/d/([a-zA-Z0-9_-]+)'),
      RegExp(r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)'),
    ];
    
    for (final pattern in googleDrivePatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        apkUrl = match.group(0);
        // 완전한 URL이 아닌 경우 https:// 추가
        if (!apkUrl!.startsWith('https://')) {
          apkUrl = 'https://$apkUrl';
        }
        print('✅ 릴리즈 노트에서 Google Drive 링크 발견: $apkUrl');
        break;
      }
    }
    
    // GitHub assets에서도 확인 (백업)
    if (apkUrl == null && json['assets'] != null && json['assets'] is List) {
      final assets = json['assets'] as List;
      for (var asset in assets) {
        if (asset['name'] != null && asset['name'].toString().endsWith('.apk')) {
          apkUrl = asset['browser_download_url'];
          break;
        }
      }
    }

    // 빌드 번호 추출 (태그에서 +뒤의 숫자)
    int? buildNum;
    final tagName = json['tag_name'] ?? '';
    if (tagName.contains('+')) {
      final parts = tagName.split('+');
      if (parts.length > 1) {
        buildNum = int.tryParse(parts[1]);
      }
    }

    return ReleaseInfo(
      name: json['name'] ?? '이름 없음',
      tagName: tagName,
      body: json['body'] ?? '',
      htmlUrl: json['html_url'] ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now(),
      downloadUrl: apkUrl,
      buildNumber: buildNum,
    );
  }
}

/// 업데이트 확인 결과를 담는 클래스
class UpdateCheckResult {
  final bool hasUpdate;
  final String currentVersion;
  final int currentBuildNumber;
  final String? latestVersion;
  final int? latestBuildNumber;
  final ReleaseInfo? releaseInfo;
  final String? errorMessage;

  UpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    required this.currentBuildNumber,
    this.latestVersion,
    this.latestBuildNumber,
    this.releaseInfo,
    this.errorMessage,
  });
} 