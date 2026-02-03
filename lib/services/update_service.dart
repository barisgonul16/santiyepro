import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/theme_colors.dart';

class UpdateService {
  // GITHUB REPO AYARLARI
  static const String _githubUser = "barisgonul16"; 
  static const String _repoName = "santiyepro";       
  
  // Version.json dosyasının ham (raw) adresi
  static const String _versionJsonUrl = "https://raw.githubusercontent.com/$_githubUser/$_repoName/main/version.json";

  // GitHub Releases sayfası
  static const String _releasesUrl = "https://github.com/$_githubUser/$_repoName/releases/latest";

  Future<void> checkForUpdates(BuildContext context) async {
    try {
      // 1. Mevcut uygulama versiyonunu al
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      Version currentVersion = Version.parse(packageInfo.version);
      
      print("LOG: Mevcut Versiyon: $currentVersion");

      // 2. İnternetteki versiyon bilgisini çek
      final response = await http.get(Uri.parse(_versionJsonUrl));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        String latestVersionStr = data['version'];
        Version latestVersion = Version.parse(latestVersionStr);
        String releaseNotes = data['notes'] ?? 'Hata düzeltmeleri ve iyileştirmeler.';

        print("LOG: Son Versiyon: $latestVersion");

        // 3. Karşılaştırma
        if (latestVersion > currentVersion) {
          // Yeni versiyon var!
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion.toString(), releaseNotes, currentVersion);
          }
        } else {
          print("LOG: Uygulama güncel.");
        }
      } else {
        print("LOG: Versiyon dosyası okunamadı: ${response.statusCode}");
      }
    } catch (e) {
      print("LOG: Güncelleme kontrol hatası: $e");
    }
  }

  Future<void> _showUpdateDialog(BuildContext context, String version, String notes, Version currentVersion) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.orange),
            const SizedBox(width: 10),
            Text("Yeni Güncelleme Mevcut!", style: TextStyle(color: ThemeColors.textPrimary(context))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Mevcut Sürüm: v${currentVersion.toString()}",
              style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 12),
            ),
            Text(
              "Yeni Sürüm: v$version",
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 15),
            Text(
              "Yenilikler:",
              style: TextStyle(color: ThemeColors.textSecondary(context), fontWeight: FontWeight.bold),
            ),
            Text(
              notes,
              style: TextStyle(color: ThemeColors.textSecondary(context)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Verileriniz güvende! Güncellemeyi yüklerken eski uygulamayı silmeyin, doğrudan üzerine kurun.",
                      style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              _launchURL(_releasesUrl);
            },
            icon: const Icon(Icons.android),
            label: const Text("Android Güncelle"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              _launchURL(_releasesUrl);
            },
            icon: const Icon(Icons.desktop_windows),
            label: const Text("Windows Güncelle"),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Link açılamadı: $url');
    }
  }
}
