import 'package:flutter_test/flutter_test.dart';
import 'package:maxxing/services/focus_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'biscuit_treats': 4});
  });

  test('running session snapshot restores its absolute end time', () async {
    final store = FocusSessionStore();
    final endTimestamp = DateTime.now()
        .add(const Duration(minutes: 5))
        .millisecondsSinceEpoch;

    await store.save(
      FocusSessionSnapshot(
        state: 'running',
        selectedMinutes: 25,
        remainingSeconds: 300,
        endTimestampMs: endTimestamp,
        sessionId: 'running-session',
        completed: false,
        rewarded: false,
        rewardPending: false,
        rewardBaseTreats: null,
      ),
    );

    final restored = await store.load();
    expect(restored.isRunning, isTrue);
    expect(restored.endTimestampMs, endTimestamp);
    expect(restored.sessionId, 'running-session');
  });

  test('paused session cannot receive a completion reward', () async {
    final store = FocusSessionStore();
    await store.save(
      FocusSessionSnapshot(
        state: 'paused',
        selectedMinutes: 25,
        remainingSeconds: 900,
        endTimestampMs: null,
        sessionId: 'paused-session',
        completed: false,
        rewarded: false,
        rewardPending: false,
        rewardBaseTreats: null,
      ),
    );

    expect(await store.completeAndReward('paused-session'), isFalse);
    expect((await SharedPreferences.getInstance()).getInt('biscuit_treats'), 4);
  });

  test(
    'reset clears the active session without changing treat count',
    () async {
      final store = FocusSessionStore();
      await store.save(
        FocusSessionSnapshot(
          state: 'running',
          selectedMinutes: 45,
          remainingSeconds: 1200,
          endTimestampMs: DateTime.now()
              .add(const Duration(minutes: 20))
              .millisecondsSinceEpoch,
          sessionId: 'reset-session',
          completed: false,
          rewarded: false,
          rewardPending: false,
          rewardBaseTreats: null,
        ),
      );

      await store.reset(45);

      final reset = await store.load();
      expect(reset.state, 'idle');
      expect(reset.sessionId, isNull);
      expect(reset.selectedMinutes, 45);
      expect(
        (await SharedPreferences.getInstance()).getInt('biscuit_treats'),
        4,
      );
    },
  );

  test('completed session grants exactly one treat across retries', () async {
    final store = FocusSessionStore();
    await store.save(
      FocusSessionSnapshot(
        state: 'running',
        selectedMinutes: 25,
        remainingSeconds: 0,
        endTimestampMs: DateTime.now().millisecondsSinceEpoch,
        sessionId: 'completed-session',
        completed: false,
        rewarded: false,
        rewardPending: false,
        rewardBaseTreats: null,
      ),
    );

    expect(await store.completeAndReward('completed-session'), isTrue);
    expect(await store.completeAndReward('completed-session'), isTrue);
    expect((await SharedPreferences.getInstance()).getInt('biscuit_treats'), 5);

    final completed = await store.load();
    expect(completed.completed, isTrue);
    expect(completed.rewarded, isTrue);
    expect(completed.rewardPending, isFalse);
  });
}
