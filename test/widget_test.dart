// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';

void main() {
  testWidgets('MedTime uygulama yükleme testi', (WidgetTester tester) async {
    // Uygulamayı başlat
    await tester.pumpWidget(const MedTimeApp());

    // Ana sayfanın yüklendiğini kontrol et 
    expect(find.textContaining('Günaydın'), findsOneWidget);
  });
}