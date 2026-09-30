import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_config.dart';
import 'app_log.dart';

class ImageService {
  // Cloudinary yapılandırması derleme zamanında verilir (bkz. AppConfig).
  static String get _baseUrl =>
      'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload';

  /// Tek fotoğraf için yükleme sınırı. Cloudinary ücretsiz planının görsel
  /// başına sınırıyla birebir aynı (10 MB = 10485760 bayt); üstündeki dosyayı
  /// Cloudinary zaten reddeder, göndermek sadece kullanıcının mobil verisini
  /// boşa harcar.
  static const int _maksYuklemeBoyutu = 10 * 1024 * 1024;

  static const Set<String> _izinliUzantilar = {
    '.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif',
  };

  Future<String?> uploadImage(String localPath) async {
    if (!AppConfig.cloudinaryHazir) {
      appLog('LOG: Cloudinary yapılandırılmamış — fotoğraf buluta yüklenemiyor. '
          'Derleme --dart-define-from-file=secrets.json ile yapılmalı.');
      return null;
    }
    try {
      File file = File(localPath);
      if (!await file.exists()) {
        appLog('LOG: Image upload error - File does not exist at $localPath');
        return null;
      }

      // Cloudinary ücretsiz kotası bant genişliği üzerinden sayılıyor.
      // Yanlışlıkla seçilen dev bir dosya (ekran kaydı, RAW fotoğraf) aylık
      // kotayı tek başına yiyebilir; bu yüzden yüklemeden önce sınırlanıyor.
      final int boyut = await file.length();
      if (boyut > _maksYuklemeBoyutu) {
        appLog('LOG: Fotograf cok buyuk (${(boyut / 1024 / 1024).toStringAsFixed(1)} MB) '
            've yuklenmedi. Sinir: ${_maksYuklemeBoyutu ~/ (1024 * 1024)} MB.');
        return null;
      }

      final String uzanti = path.extension(localPath).toLowerCase();
      if (!_izinliUzantilar.contains(uzanti)) {
        appLog('LOG: Desteklenmeyen dosya turu ($uzanti), yuklenmedi.');
        return null;
      }

      appLog('LOG: Preparing Cloudinary upload for ${path.basename(localPath)}');

      // Multipart request oluştur
      var request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
      
      // Gerekli alanları ekle (Unsigned Upload için)
      request.fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;
      
      // Dosyayı ekle
      request.files.add(await http.MultipartFile.fromPath(
        'file', 
        localPath,
      ));

      appLog('LOG: Sending request to Cloudinary...');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        String downloadUrl = data['secure_url'];
        appLog('LOG: Successfully received Cloudinary URL: $downloadUrl');
        return downloadUrl;
      } else {
        appLog('LOG: Cloudinary Error (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      appLog('LOG: Generic Image upload error: $e');
      return null;
    }
  }

  Future<Uint8List?> downloadImage(String url) async {
    try {
      appLog('LOG: Downloading image from $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        appLog('LOG: Download error (${response.statusCode})');
        return null;
      }
    } catch (e) {
      appLog('LOG: Generic Download error: $e');
      return null;
    }
  }

  static bool isNetworkUrl(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  static Widget buildImage(String? path, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (path == null || path.trim().isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.black26,
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.white38, size: 30),
        ),
      );
    }

    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    
    if (isNetwork) {
      String displayUrl = path;
      if (path.contains('res.cloudinary.com') && !path.contains('/w_')) {
        displayUrl = path.replaceFirst('/upload/', '/upload/w_800,c_limit,q_auto/');
      }

      return CachedNetworkImage(
        imageUrl: displayUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: Colors.black26,
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
            ),
          ),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, color: Colors.white54, size: 30),
            ],
          ),
        ),
      );
    } else {
      bool exists = false;
      bool isMobilePathOnWindows = false;
      try {
        final file = File(path);
        exists = file.existsSync();
        isMobilePathOnWindows = Platform.isWindows && 
            (path.startsWith('/data/') || path.startsWith('/storage/'));
      } catch (e) {
        exists = false;
      }

      if (!exists) {
        return Container(
          width: width,
          height: height,
          color: Colors.black26,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isMobilePathOnWindows ? Icons.cloud_off : Icons.image_not_supported,
                  color: Colors.white38,
                  size: 30,
                ),
                if (isMobilePathOnWindows)
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Mobilden yüklenmeli',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      try {
        return Image.file(
          File(path),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
          ),
        );
      } catch (e) {
        return const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
        );
      }
    }
  }
}
