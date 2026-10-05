import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/theme_colors.dart';
import 'app_log.dart';

class UpdateService {
  // GITHUB REPO AYARLARI
  static const String _githubUser = "barisgonul16";
  static const String _repoName = "santiyepro";

  // Version.json dosyasının ham (raw) adresi
  static const String _versionJsonUrl = "https://raw.githubusercontent.com/$_githubUser/$_repoName/main/version.json";

  // GitHub Releases sayfası
  static const String _releasesUrl = "https://github.com/$_githubUser/$_repoName/releases/latest";

  // En son yayındaki kurulum dosyalarının doğrudan indirme adresleri. Dosya
  // adları her yayında aynı kaldığı sürece GitHub bunları en yeni yayına
  // yönlendirir; yayın sayfasında dosya aramaya gerek kalmaz.
  static const String _apkUrl = "$_releasesUrl/download/app-release.apk";
  static const String _msixUrl = "$_releasesUrl/download/santiyepro.msix";

  Future<void> checkForUpdates(BuildContext context, {bool showSnackBarIfUpdated = false}) async {
    try {
      // 1. Mevcut uygulama versiyonunu al
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersionStr = packageInfo.version;
      String currentBuildStr = packageInfo.buildNumber;

      appLog("LOG: Mevcut Versiyon: $currentVersionStr+$currentBuildStr");

      // 2. İnternetteki versiyon bilgisini çek (cache önlemek için timestamp eklendi)
      final String cacheBustUrl = "$_versionJsonUrl?t=${DateTime.now().millisecondsSinceEpoch}";
      final response = await http.get(Uri.parse(cacheBustUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        String latestVersionFull = data['version'];
        String releaseNotes = data['notes'] ?? 'Hata düzeltmeleri ve iyileştirmeler.';

        // Parse version and build number (format: "1.0.2+5")
        String latestVersionStr = latestVersionFull;
        int latestBuildNum = 0;
        if (latestVersionFull.contains('+')) {
          final parts = latestVersionFull.split('+');
          latestVersionStr = parts[0];
          latestBuildNum = int.tryParse(parts[1]) ?? 0;
        }

        int currentBuildNum = int.tryParse(currentBuildStr) ?? 0;

        appLog("LOG: Son Versiyon: $latestVersionStr+$latestBuildNum");

        // 3. Karşılaştırma - önce semantic version, sonra build number
        Version currentVersion = Version.parse(currentVersionStr);
        Version latestVersion = Version.parse(latestVersionStr);

        bool needsUpdate = false;
        if (latestVersion > currentVersion) {
          needsUpdate = true;
        } else if (latestVersion == currentVersion && latestBuildNum > currentBuildNum) {
          needsUpdate = true;
        }

        if (needsUpdate) {
          // Yeni versiyon var!
          if (context.mounted) {
            _showUpdateDialog(context, latestVersionFull, releaseNotes, currentVersion);
          }
        } else {
          appLog("LOG: Uygulama güncel.");
          if (showSnackBarIfUpdated && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Uygulamanız zaten en son sürümde (v$currentVersionStr+$currentBuildStr)."),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        appLog("LOG: Versiyon dosyası okunamadı: ${response.statusCode}");
        if (showSnackBarIfUpdated && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Sunucudan versiyon bilgisi alınamadı (Kod: ${response.statusCode})."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      appLog("LOG: Güncelleme kontrol hatası: $e");
      if (showSnackBarIfUpdated && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Güncelleme kontrolünde hata oluştu: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showUpdateDialog(BuildContext context, String version, String notes, Version currentVersion) async {
    final String sonrakiAdim = Platform.isAndroid
        ? "İndirme bitince dosyaya dokunup \"Güncelle\" de."
        : Platform.isWindows
            ? "İndirilen dosyaya çift tıklayıp \"Güncelleştir\" de."
            : "Açılan sayfadan cihazına uygun dosyayı indir.";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.cardBackground(context),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text("Yeni güncelleme var", style: TextStyle(color: ThemeColors.textPrimary(context))),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Mevcut Sürüm: v${currentVersion.toString()}",
                style: TextStyle(color: ThemeColors.textTertiary(context), fontSize: 12),
              ),
              Text(
                "Yeni Sürüm: v$version",
                style: TextStyle(color: ThemeColors.iyi(context), fontWeight: FontWeight.bold, fontSize: 16),
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
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "$sonrakiAdim Verilerin güvende: eski uygulamayı silme, üzerine kur.",
                        style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Sonra"),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
            onPressed: _guncellemeyiIndir,
            icon: const Icon(Icons.download),
            label: const Text("İndir ve güncelle"),
          ),
        ],
      ),
    );
  }

  /// Cihaza uygun kurulum dosyasını doğrudan indirir. Dosya son yayında yoksa
  /// (ya da adrese ulaşılamıyorsa) yayın sayfası açılır.
  Future<void> _guncellemeyiIndir() async {
    final String? dogrudan = Platform.isAndroid
        ? _apkUrl
        : Platform.isWindows
            ? _msixUrl
            : null;
    String hedef = _releasesUrl;
    if (dogrudan != null) {
      try {
        final yanit = await http.head(Uri.parse(dogrudan)).timeout(const Duration(seconds: 8));
        if (yanit.statusCode == 200) hedef = dogrudan;
      } catch (e) {
        appLog("LOG: Doğrudan indirme adresi doğrulanamadı: $e");
      }
    }
    try {
      await _launchURL(hedef);
    } catch (e) {
      appLog("LOG: Güncelleme adresi açılamadı: $e");
      if (hedef != _releasesUrl) {
        try {
          await _launchURL(_releasesUrl);
        } catch (_) {}
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Link açılamadı: $url');
    }
  }
}
