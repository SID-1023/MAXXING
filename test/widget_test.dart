import 'package:flutter_test/flutter_test.dart';
import 'package:maxxing/main.dart';

void main() {
  testWidgets('MAXXING app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MaxxingApp());

    expect(find.text('MAXXING'), findsWidgets);
  });
}
