import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxxing/main.dart';
import 'package:maxxing/screens/focus_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MAXXING app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MaxxingApp());

    expect(find.text('MAXXING'), findsWidgets);
  });

  testWidgets('Focus timer starts while the dimension transition plays', (
    WidgetTester tester,
  ) async {
    var soundPlayCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FocusScreen(
          onStartSound: () async {
            soundPlayCount++;
          },
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();

    expect(find.text('25:00'), findsOneWidget);
    await tester.ensureVisible(find.text('START QUEST'));
    await tester.pump();
    await tester.tap(find.text('START QUEST'));
    await tester.pump();

    expect(find.text('ENTERING DIMENSION'), findsOneWidget);
    expect(soundPlayCount, 1);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.text('25:00'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('PAUSE QUEST'), findsOneWidget);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('24:59'), findsOneWidget);

    await tester.tap(find.text('PAUSE QUEST'));
    await tester.pump();
    expect(find.text('RESUME QUEST'), findsOneWidget);

    await tester.tap(find.text('RESUME QUEST'));
    await tester.pump();
    expect(find.text('ENTERING DIMENSION'), findsNothing);
    expect(soundPlayCount, 1);

    await tester.tap(find.text('PAUSE QUEST'));
    await tester.pump();
    expect(find.text('RESUME QUEST'), findsOneWidget);

    await tester.tap(find.byTooltip('Reset timer'));
    await tester.pump();
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('START QUEST'), findsOneWidget);

    await tester.tap(find.text('START QUEST'));
    await tester.pump();
    expect(find.text('ENTERING DIMENSION'), findsOneWidget);
    expect(soundPlayCount, 2);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text('PAUSE QUEST'), findsOneWidget);
  });
}
