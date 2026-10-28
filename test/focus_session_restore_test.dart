import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxxing/screens/focus_screen.dart';
import 'package:maxxing/services/focus_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('paused focus session restores without replaying the entrance', (
    WidgetTester tester,
  ) async {
    final store = FocusSessionStore();
    await store.save(
      FocusSessionSnapshot(
        state: 'paused',
        selectedMinutes: 25,
        remainingSeconds: 600,
        endTimestampMs: null,
        sessionId: 'paused-restore',
        completed: false,
        rewarded: false,
        rewardPending: false,
        rewardBaseTreats: null,
      ),
    );
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('RESUME QUEST'), findsOneWidget);
    expect(find.text('ENTERING DIMENSION'), findsNothing);
    expect(soundPlayCount, 0);
  });
}
