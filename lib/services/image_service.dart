import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ImageService {
  // Cloudinary Yapılandırması
  static const String _cloudName = 'dcsrpayi6';
  static const String _uploadPreset = 'şantiyepro';
  static const String _baseUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  Future<String?> uploadImage(String localPath) async {
    try {
      File file = File(localPath);
      if (!await file.exists()) {
        print('LOG: Image upload error - File does not exist at $localPath');
        return null;
      }

      print('LOG: Preparing Cloudinary upload for ${path.basename(localPath)}');

      // Multipart request oluştur
      var request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
      
      // Gerekli alanları ekle (Unsigned Upload için)
      request.fields['upload_preset'] = _uploadPreset;
      
      // Dosyayı ekle
      request.files.add(await http.MultipartFile.fromPath(
        'file', 
        localPath,
      ));

      print('LOG: Sending request to Cloudinary...');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        String downloadUrl = data['secure_url'];
        print('LOG: Successfully received Cloudinary URL: $downloadUrl');
        return downloadUrl;
      } else {
        print('LOG: Cloudinary Error (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      print('LOG: Generic Image upload error: $e');
      return null;
    }
  }

  Future<Uint8List?> downloadImage(String url) async {
    try {
      print('LOG: Downloading image from $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print('LOG: Download error (${response.statusCode})');
        return null;
      }
    } catch (e) {
      print('LOG: Generic Download error: $e');
      return null;
    }
  }

  static bool isNetworkUrl(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  static Widget buildImage(String path, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    
    if (isNetwork) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, color: Colors.white54, size: 30),
            ],
          ),
        ),
      );
    } else {
      final file = File(path);
      if (!file.existsSync()) {
        bool isMobilePathOnWindows = Platform.isWindows && 
            (path.startsWith('/data/') || path.startsWith('/storage/'));
        
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

      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
        ),
      );
    }
  }
}
