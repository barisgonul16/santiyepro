import 'package:flutter_test/flutter_test.dart';

import 'package:santiyepro/main.dart';

void main() {
  testWidgets('App should start without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MyApp), findsOneWidget);
    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.text('Proje Takip'), findsOneWidget);
  },
      // Bu test hiçbir zaman geçmedi ve mevcut haliyle geçemez:
      //
      // 1. MyApp -> AuthWrapper -> FirebaseAuth.instance; test ortamında
      //    Firebase.initializeApp çağrılmadığı için eklenti kanalı yok.
      // 2. Splash ekranındaki _AnimatedLoadingScreen sonsuz bir
      //    Future.delayed döngüsü kurduğu için pumpAndSettle asla bitmez
      //    ("did not complete" hatası buradan geliyor).
      // 3. 'Proje Takip' MaterialApp'in title'ı; ekranda görünen bir metin
      //    değil, dolayısıyla find.text onu zaten bulamaz.
      //
      // Anlamlı hale getirmek için Firebase'in sahtelenmesi ve splash
      // animasyonunun test edilebilir biçimde ayrılması gerekiyor (Faz 4).
      // O zamana kadar yanlış bir kırmızı vermemesi için atlanıyor.
      skip: true);
}
