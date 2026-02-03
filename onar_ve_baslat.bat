@echo off
echo ==========================================
echo SantiyePro Onarim ve Baslatma Araci
echo ==========================================

echo 1. Gecici dosyalar temizleniyor (flutter clean)...
call flutter clean

echo 2. Kutuphaneler indiriliyor (flutter pub get)...
call flutter pub get

echo 3. Android build dosyalari onariliyor...
if exist "android\.gradle" rmdir /s /q "android\.gradle"

echo 4. Uygulama baslatiliyor (flutter run)...
echo Lutfen telefonunuzun kilidini acin ve bekleyin.
call flutter run

pause
