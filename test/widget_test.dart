import 'package:flutter_test/flutter_test.dart';

import 'package:santiyepro/main.dart';

void main() {
  testWidgets('App should start without crashing', (WidgetTester tester) async {
    // Uygulamayı başlat
    await tester.pumpWidget(const MyApp());

    // MyApp widget'ının yüklendiğini doğrula
    expect(find.byType(MyApp), findsOneWidget);

    // Ana ekranın yüklendiğini doğrula
    expect(find.byType(MainScreen), findsOneWidget);

    // Sol menüde "Proje Takip" başlığını ara
    expect(find.text('Proje Takip'), findsOneWidget);
  });
}
