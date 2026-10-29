import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxxing/screens/focus_screen.dart';
import 'package:maxxing/services/focus_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'starting persists the session if backgrounded during the entrance animation',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: FocusScreen(
            onStartSound: () async {},
            onCompleteSound: () async {},
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('START QUEST'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START QUEST'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      final session = await FocusSessionStore().load();
      expect(session.isRunning, isTrue);
      expect(session.sessionId, isNotNull);
      expect(
        session.endTimestampMs,
        greaterThan(DateTime.now().millisecondsSinceEpoch),
      );
    },
  );
}
