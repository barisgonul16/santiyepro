import java.io.FileInputStream
import java.util.Properties

// Release imzalama anahtarı. android/key.properties dosyası VARSA release
// derlemesi gerçek anahtarla imzalanır; YOKSA eskisi gibi debug anahtarıyla
// imzalanır. Böylece anahtarı olmayan bir makinede derleme kırılmaz.
//
// DİKKAT: İmzalama anahtarını değiştirmek, mevcut kurulu uygulamaların
// üzerine güncelleme yapılmasını ENGELLER (imza uyuşmazlığı). Geçiş için
// kullanıcıların önce Ayarlar > Yedek Al ile yedek alması, uygulamayı
// kaldırıp yeniden kurması ve yedeği geri yüklemesi gerekir.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val releaseKeyVar = keystorePropertiesFile.exists()
if (releaseKeyVar) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.santiyepro"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.santiyepro"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        multiDexEnabled = true
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseKeyVar) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseKeyVar) {
                signingConfigs.getByName("release")
            } else {
                // Anahtar yok: mevcut davranış korunur.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}


