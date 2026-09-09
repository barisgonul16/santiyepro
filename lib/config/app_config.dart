/// Derleme zamanında verilen gizli yapılandırma.
///
/// Değerler kaynak kodda DEĞİL, git tarafından yok sayılan `secrets.json`
/// dosyasında durur ve derlemeye şöyle aktarılır:
///
///   flutter build windows --release --dart-define-from-file=secrets.json
///   flutter build apk     --release --dart-define-from-file=secrets.json
///   flutter run                     --dart-define-from-file=secrets.json
///
/// Şablon için `secrets.example.json` dosyasına bakın.
///
/// Not: Bu yöntem değerleri depodan çıkarır ama derlenmiş uygulamanın içinden
/// çıkarılmalarını engellemez. İstemci uygulamalarda gerçek sır saklanamaz;
/// asıl koruma sağlayıcı panelindeki kısıtlardır (Cloudinary preset limitleri,
/// OAuth yönlendirme adresi kısıtı).
library;

class AppConfig {
  static const String googleClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const String googleClientSecret =
      String.fromEnvironment('GOOGLE_CLIENT_SECRET');
  static const String cloudinaryCloudName =
      String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const String cloudinaryUploadPreset =
      String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');

  /// Masaüstünde Google ile giriş yapılabilir mi?
  static bool get googleMasaustuHazir =>
      googleClientId.isNotEmpty && googleClientSecret.isNotEmpty;

  /// Fotoğraflar buluta yüklenebilir mi?
  static bool get cloudinaryHazir =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  /// Eksik yapılandırma anahtarları. Boş değilse derleme `secrets.json`
  /// olmadan yapılmıştır ve ilgili özellikler çalışmaz.
  static List<String> get eksikAyarlar {
    final eksik = <String>[];
    if (googleClientId.isEmpty) eksik.add('GOOGLE_CLIENT_ID');
    if (googleClientSecret.isEmpty) eksik.add('GOOGLE_CLIENT_SECRET');
    if (cloudinaryCloudName.isEmpty) eksik.add('CLOUDINARY_CLOUD_NAME');
    if (cloudinaryUploadPreset.isEmpty) eksik.add('CLOUDINARY_UPLOAD_PRESET');
    return eksik;
  }
}
