# Dosya Toplama Scripti
$version = "v1.0.1_4"
$targetDir = "SantiyePro_Kurulum"
$androidSource = "build\app\outputs\flutter-apk\app-release.apk"
$windowsSource = "build\windows\x64\runner\Release"

Write-Host "📂 Kurulum dosyaları toplanıyor..." -ForegroundColor Cyan

# Klasörleri Oluştur
New-Item -ItemType Directory -Force -Path "$targetDir\Android" | Out-Null
New-Item -ItemType Directory -Force -Path "$targetDir\Windows" | Out-Null

# Android APK Kopyala
if (Test-Path $androidSource) {
    Copy-Item $androidSource -Destination "$targetDir\Android\SantiyePro_$version.apk" -Force
    Write-Host "✅ Android APK kopyalandı." -ForegroundColor Green
} else {
    Write-Host "⚠️ Android APK bulunamadı. Derleme başarısız olmuş olabilir." -ForegroundColor Yellow
}

# Windows Dosyalarını Kopyala
if (Test-Path "$windowsSource\SantiyePro.exe") {
    Copy-Item "$windowsSource\*" -Destination "$targetDir\Windows" -Recurse -Force
    Write-Host "✅ Windows dosyaları kopyalandı." -ForegroundColor Green
    
    # Zip Oluştur (Opsiyonel)
    $compress = @{
        Path = "$targetDir\Windows"
        CompressionLevel = "Fastest"
        DestinationPath = "$targetDir\SantiyePro_Windows_$version.zip"
        Force = $true
    }
    Compress-Archive @compress
    Write-Host "📦 Windows versiyonu ziplendi." -ForegroundColor Green
} else {
    Write-Host "⚠️ Windows build dosyaları bulunamadı. Derleme devam ediyor olabilir." -ForegroundColor Yellow
}

Invoke-Item $targetDir
Write-Host "🚀 İşlem tamamlandı!" -ForegroundColor Cyan
