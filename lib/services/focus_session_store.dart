import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusSessionSnapshot {
  const FocusSessionSnapshot({
    required this.state,
    required this.selectedMinutes,
    required this.remainingSeconds,
    required this.endTimestampMs,
    required this.sessionId,
    required this.completed,
    required this.rewarded,
    required this.rewardPending,
    required this.rewardBaseTreats,
  });

  factory FocusSessionSnapshot.ready({int selectedMinutes = 25}) {
    return FocusSessionSnapshot(
      state: 'idle',
      selectedMinutes: selectedMinutes,
      remainingSeconds: selectedMinutes * 60,
      endTimestampMs: null,
      sessionId: null,
      completed: false,
      rewarded: false,
      rewardPending: false,
      rewardBaseTreats: null,
    );
  }

  factory FocusSessionSnapshot.fromJson(Map<String, dynamic> json) {
    final selectedMinutes = _boundedInt(
      json['selectedDurationMinutes'],
      25,
      1,
      600,
    );
    final remainingSeconds = _boundedInt(
      json['remainingSeconds'],
      selectedMinutes * 60,
      0,
      selectedMinutes * 60,
    );
    final rawState = json['state'];
    final state =
        rawState == 'running' || rawState == 'paused' || rawState == 'completed'
        ? rawState as String
        : 'idle';

    return FocusSessionSnapshot(
      state: state,
      selectedMinutes: selectedMinutes,
      remainingSeconds: remainingSeconds,
      endTimestampMs:
          json['endTimestampMs'] is int && (json['endTimestampMs'] as int) > 0
          ? json['endTimestampMs'] as int
          : null,
      sessionId: json['sessionId'] is String
          ? json['sessionId'] as String
          : null,
      completed: json['completed'] == true,
      rewarded: json['rewarded'] == true,
      rewardPending: json['rewardPending'] == true,
      rewardBaseTreats: json['rewardBaseTreats'] is int
          ? json['rewardBaseTreats'] as int
          : null,
    );
  }

  final String state;
  final int selectedMinutes;
  final int remainingSeconds;
  final int? endTimestampMs;
  final String? sessionId;
  final bool completed;
  final bool rewarded;
  final bool rewardPending;
  final int? rewardBaseTreats;

  bool get isRunning => state == 'running';
  bool get isPaused => state == 'paused';

  Map<String, Object?> toJson() => {
    'state': state,
    'selectedDurationMinutes': selectedMinutes,
    'remainingSeconds': remainingSeconds,
    'endTimestampMs': endTimestampMs,
    'sessionId': sessionId,
    'completed': completed,
    'rewarded': rewarded,
    'rewardPending': rewardPending,
    'rewardBaseTreats': rewardBaseTreats,
  };

  FocusSessionSnapshot copyWith({
    String? state,
    int? selectedMinutes,
    int? remainingSeconds,
    int? endTimestampMs,
    String? sessionId,
    bool? completed,
    bool? rewarded,
    bool? rewardPending,
    int? rewardBaseTreats,
    bool clearEndTimestamp = false,
    bool clearSessionId = false,
    bool clearRewardBaseTreats = false,
  }) {
    return FocusSessionSnapshot(
      state: state ?? this.state,
      selectedMinutes: selectedMinutes ?? this.selectedMinutes,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      endTimestampMs: clearEndTimestamp
          ? null
          : endTimestampMs ?? this.endTimestampMs,
      sessionId: clearSessionId ? null : sessionId ?? this.sessionId,
      completed: completed ?? this.completed,
      rewarded: rewarded ?? this.rewarded,
      rewardPending: rewardPending ?? this.rewardPending,
      rewardBaseTreats: clearRewardBaseTreats
          ? null
          : rewardBaseTreats ?? this.rewardBaseTreats,
    );
  }

  static int _boundedInt(
    Object? value,
    int fallback,
    int minimum,
    int maximum,
  ) {
    if (value is! int) return fallback;
    return value.clamp(minimum, maximum);
  }
}

class FocusSessionStore {
  static const String sessionKey = 'maxxing_focus_session';
  static const String _treatsKey = 'biscuit_treats';
  static Future<void> _operationQueue = Future<void>.value();

  Future<T> _exclusive<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _operationQueue = _operationQueue.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<FocusSessionSnapshot> load() {
    return () async {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(sessionKey);
      if (saved == null) return FocusSessionSnapshot.ready();

      try {
        final decoded = jsonDecode(saved);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Focus session must be a JSON object.');
        }
        return FocusSessionSnapshot.fromJson(decoded);
      } on FormatException catch (error) {
        debugPrint(
          'Invalid saved focus session; restoring ready state: $error',
        );
        return FocusSessionSnapshot.ready();
      }
    }();
  }

  Future<void> save(FocusSessionSnapshot snapshot) {
    return _exclusive(() async {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(
        sessionKey,
        jsonEncode(snapshot.toJson()),
      );
      if (!saved) throw StateError('Could not persist focus session.');
    });
  }

  Future<void> reset(int selectedMinutes) {
    return save(FocusSessionSnapshot.ready(selectedMinutes: selectedMinutes));
  }

  Future<bool> completeAndReward(String sessionId) {
    return _exclusive(() async {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = await _readSnapshot(prefs);
      if (snapshot.sessionId != sessionId || snapshot.state == 'idle') {
        return false;
      }
      if (snapshot.rewarded) return true;
      final isExpiredRunningSession =
          snapshot.isRunning &&
          snapshot.endTimestampMs != null &&
          snapshot.endTimestampMs! <= DateTime.now().millisecondsSinceEpoch;
      final isPendingCompletion =
          snapshot.state == 'completed' && snapshot.rewardPending;
      if (!isExpiredRunningSession && !isPendingCompletion) {
        return false;
      }

      final treatsValue = prefs.get(_treatsKey);
      final currentTreats = treatsValue is int ? treatsValue : 5;
      final baseTreats =
          snapshot.rewardPending && snapshot.rewardBaseTreats != null
          ? snapshot.rewardBaseTreats!
          : currentTreats;

      var completing = snapshot.copyWith(
        state: 'completed',
        remainingSeconds: 0,
        clearEndTimestamp: true,
        completed: true,
        rewardPending: true,
        rewardBaseTreats: baseTreats,
      );
      await _writeSnapshot(prefs, completing);

      if (currentTreats <= baseTreats) {
        final savedTreats = await prefs.setInt(_treatsKey, baseTreats + 1);
        if (!savedTreats) {
          throw StateError('Could not save Biscuit focus reward.');
        }
      }

      completing = completing.copyWith(rewarded: true, rewardPending: false);
      await _writeSnapshot(prefs, completing);
      debugPrint('Focus session $sessionId completed and rewarded once.');
      return true;
    });
  }

  Future<FocusSessionSnapshot> _readSnapshot(SharedPreferences prefs) async {
    final saved = prefs.getString(sessionKey);
    if (saved == null) return FocusSessionSnapshot.ready();
    try {
      final decoded = jsonDecode(saved);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Focus session must be a JSON object.');
      }
      return FocusSessionSnapshot.fromJson(decoded);
    } on FormatException catch (error) {
      debugPrint('Invalid saved focus session: $error');
      return FocusSessionSnapshot.ready();
    }
  }

  Future<void> _writeSnapshot(
    SharedPreferences prefs,
    FocusSessionSnapshot snapshot,
  ) async {
    final saved = await prefs.setString(
      sessionKey,
      jsonEncode(snapshot.toJson()),
    );
    if (!saved) throw StateError('Could not persist focus session state.');
  }
}
