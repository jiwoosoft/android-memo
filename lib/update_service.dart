import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart'; // 🔴 꼭 추가

class UpdateService {
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = int.parse(packageInfo.buildNumber);

      final response = await http.get(Uri.parse('https://drive.google.com/uc?export=download&id=1uOBHu09UmUm5TeWeo3bEyYAr7tr9--nx'));
      if (response.statusCode != 200) throw Exception('버전 정보를 가져오지 못했습니다.');

      final data = json.decode(response.body);
      final latestVersion = data['version'];
      final latestBuild = data['build'];
      final apkUrl = data['apk_url'];

      if (_isNewerVersion(currentVersion, latestVersion, currentBuild, latestBuild)) {
        _showUpdateDialog(context, latestVersion, apkUrl);
      }
    } catch (e) {
      print('업데이트 확인 중 오류 발생: $e');
    }
  }

  static bool _isNewerVersion(String current, String latest, int currentBuild, int latestBuild) {
    if (current == latest) return latestBuild > currentBuild;
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return latestBuild > currentBuild;
  }

  static void _showUpdateDialog(BuildContext context, String version, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('업데이트 알림'),
        content: Text('최신 버전($version)이 있습니다. 지금 업데이트하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _launchUrl(apkUrl);
            },
            child: const Text('업데이트'),
          ),
        ],
      ),
    );
  }

  static void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'URL 실행 실패: $url';
    }
  }
}
