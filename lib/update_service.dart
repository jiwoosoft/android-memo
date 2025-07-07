import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String versionInfoUrl =
      'https://drive.google.com/uc?export=download&id=1e_1s7h3v_example_version_json_id'; // ⚠️ version.json 공유 링크의 ID로 교체하세요

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(versionInfoUrl));

      if (response.statusCode == 200) {
        final remote = json.decode(response.body);

        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        final currentBuild = int.parse(packageInfo.buildNumber);

        final remoteVersion = remote['version'];
        final remoteBuild = remote['build'];
        final apkUrl = remote['apk_url'];

        if (_isNewerVersion(currentVersion, remoteVersion, currentBuild, remoteBuild)) {
          _showUpdateDialog(context, apkUrl);
        }
      }
    } catch (e) {
      print('업데이트 확인 실패: $e');
    }
  }

  static bool _isNewerVersion(String currentVersion, String remoteVersion, int currentBuild, int remoteBuild) {
    final cvParts = currentVersion.split('.').map(int.parse).toList();
    final rvParts = remoteVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      if (rvParts[i] > cvParts[i]) return true;
      if (rvParts[i] < cvParts[i]) return false;
    }
    return remoteBuild > currentBuild;
  }

  static void _showUpdateDialog(BuildContext context, String apkUrl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('새 버전 발견'),
        content: Text('새로운 버전이 있습니다. 업데이트하시겠습니까?'),
        actions: [
          TextButton(
            child: Text('취소'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('업데이트'),
            onPressed: () async {
              Navigator.of(context).pop();
              if (await canLaunchUrl(Uri.parse(apkUrl))) {
                await launchUrl(Uri.parse(apkUrl), mode: LaunchMode.externalApplication);
              }
            },
          )
        ],
      ),
    );
  }
}
