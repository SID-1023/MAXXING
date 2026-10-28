import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxxing/screens/focus_screen.dart';
import 'package:maxxing/services/focus_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('expired restored quest completes and rewards once', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'biscuit_treats': 4});
    final store = FocusSessionStore();
    await store.save(
      FocusSessionSnapshot(
        state: 'running',
        selectedMinutes: 1,
        remainingSeconds: 0,
        endTimestampMs: DateTime.now()
            .subtract(const Duration(seconds: 1))
            .millisecondsSinceEpoch,
        sessionId: 'expired-restore',
        completed: false,
        rewarded: false,
        rewardPending: false,
        rewardBaseTreats: null,
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: FocusScreen()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('QUEST COMPLETE!'), findsNWidgets(2));
    expect((await SharedPreferences.getInstance()).getInt('biscuit_treats'), 5);
  });
}
