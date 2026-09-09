import 'package:flutter/foundation.dart';

/// Uygulama günlüğü.
///
/// Release derlemelerinde tamamen susar. Sebebi: bu uygulamanın logları
/// e-posta adresi, dosya yolları, Firebase anahtarları ve hata ayrıntıları
/// içeriyor. Bunların son kullanıcının cihazında tutulması gerekmiyor.
///
/// Geliştirme (debug/profile) derlemelerinde her şey eskisi gibi görünür.
void appLog(Object? mesaj) {
  if (kReleaseMode) return;
  debugPrint(mesaj?.toString());
}
