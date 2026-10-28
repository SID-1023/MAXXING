import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../services/focus_session_store.dart';

// MAXXING theme
const Color _background = Color(0xFF17132B);
const Color _purple = Color(0xFFFFD66B); // Primary yellow accent
const Color _card = Color(0xFF241D42);
const Color _cream = Color(0xFFF6EFE3);
const Color _coral = Color(0xFFFF8A65);
const Color _mint = Color(0xFF7ED9B0);
const Color _softText = Color(0xFFBEB5D5);

/// Dialog for selecting a custom focus duration.
class _CustomDurationDialog extends StatefulWidget {
  const _CustomDurationDialog();

  @override
  State<_CustomDurationDialog> createState() => _CustomDurationDialogState();
}

class _CustomDurationDialogState extends State<_CustomDurationDialog> {
  final TextEditingController _hoursController = TextEditingController(
    text: '0',
  );
  final TextEditingController _minutesController = TextEditingController(
    text: '30',
  );

  String? _errorMessage;

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _submit() {
    final hoursText = _hoursController.text.trim();
    final minutesText = _minutesController.text.trim();

    final int? hours = hoursText.isEmpty ? 0 : int.tryParse(hoursText);
    final int? minutes = minutesText.isEmpty ? 0 : int.tryParse(minutesText);

    if (hours == null ||
        minutes == null ||
        hours < 0 ||
        minutes < 0 ||
        minutes > 59) {
      setState(() {
        _errorMessage =
            'Enter valid hours and minutes. Minutes must be between 0 and 59.';
      });
      return;
    }

    final totalMinutes = hours * 60 + minutes;

    if (totalMinutes < 1 || totalMinutes > 600) {
      setState(() {
        _errorMessage = 'Choose a time from 1 minute to 10 hours.';
      });
      return;
    }

    Navigator.pop(context, totalMinutes);
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _softText),
      filled: true,
      fillColor: _background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _purple, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: _purple.withValues(alpha: 0.25)),
      ),
      title: const Text(
        'CUSTOM FOCUS TIME',
        style: TextStyle(
          color: _cream,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How long do you want to focus?',
            style: TextStyle(color: _softText),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hoursController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: _cream),
                  decoration: _fieldDecoration('Hours'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: _cream),
                  decoration: _fieldDecoration('Minutes'),
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: _coral, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Choose between 1 minute and 10 hours.',
            style: TextStyle(color: _softText, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _softText)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: _background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Set duration',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class FocusScreen extends StatefulWidget {
  const FocusScreen({
    super.key,
    this.onStartSound,
    this.onCompleteSound,
  });

  final Future<void> Function()? onStartSound;
  final Future<void> Function()? onCompleteSound;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const int _distractionNotificationId = 707;
  static const Color _portalViolet = Color(0xFF9D72FF);
  static const Color _portalLavender = Color(0xFFD4C2FF);

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final FocusSessionStore _sessionStore = FocusSessionStore();
  Future<AudioPool?>? _portalAudioPool;
  Future<AudioPool?>? _completionAudioPool;
  Future<void> _portalSoundQueue = Future<void>.value();
  StopFunction? _activePortalSoundStop;
  bool _isDisposed = false;
  int _portalSoundRequestId = 0;
  late final AnimationController _dimensionController;
  late final Animation<double> _buttonScale;
  late final Animation<double> _portalProgress;
  late final Animation<double> _portalOpacity;
  late final Animation<double> _roomGlowOpacity;
  late final Animation<double> _enteringTitleOpacity;
  late final Animation<double> _activatedTitleOpacity;
  late final Animation<double> _contentScale;
  late final Animation<double> _biscuitScale;
  late final Animation<double> _timerOpacity;
  late final Animation<Offset> _timerSlide;

  Timer? _timer;
  DateTime? _endTime;
  DateTime? _leftAt;

  int _selectedMinutes = 25;
  int _remainingSeconds = 25 * 60;
  int _completedSessions = 0;
  String? _sessionId;

  bool _isRunning = false;
  bool _isSessionPaused = false;
  bool _isTransitioning = false;
  bool _sessionCompleted = false;
  bool _isCompletingSession = false;
  bool _isRestoringSession = true;
  bool _isPersistingSession = false;
  bool _isRestoringSessionInFlight = false;
  bool _guardEnabled = true;
  bool _notificationsReady = false;
  bool _notificationPermissionGranted = false;
  bool _reminderShownForInterruption = false;

  int get _totalSeconds => _selectedMinutes * 60;

  bool get _isPaused => _isSessionPaused;

  double get _progress {
    if (_totalSeconds <= 0) return 0;
    return (1 - (_remainingSeconds / _totalSeconds)).clamp(0.0, 1.0);
  }

  String get _timeText {
    final hours = _remainingSeconds ~/ 3600;
    final minutes = ((_remainingSeconds % 3600) ~/ 60).toString().padLeft(
      2,
      '0',
    );
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  String get _statusText {
    if (_sessionCompleted) return 'QUEST COMPLETE!';
    if (_isRunning) return 'BISCUIT IS COUNTING ON YOU';
    if (_isPaused) return 'QUEST PAUSED';
    return 'READY WHEN YOU ARE';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dimensionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _buttonScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0.95,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 5,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.95,
          end: 1.035,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 7,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.035,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 8,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 80),
    ]).animate(_dimensionController);
    _portalProgress = CurvedAnimation(
      parent: _dimensionController,
      curve: const Interval(0.2, 0.72, curve: Curves.easeOutCubic),
    );
    _portalOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _dimensionController,
        curve: const Interval(0.62, 1, curve: Curves.easeInCubic),
      ),
    );
    _roomGlowOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 12,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 53),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 35,
      ),
    ]).animate(_dimensionController);
    _enteringTitleOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 5,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 10),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 8,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 77),
    ]).animate(_dimensionController);
    _activatedTitleOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 65),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 8,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 17),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 10,
      ),
    ]).animate(_dimensionController);
    _contentScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 20),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.012,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.012), weight: 27),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.012,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 13),
    ]).animate(_dimensionController);
    _biscuitScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 32),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.035,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.035,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 20,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 34),
    ]).animate(_dimensionController);
    _timerOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0.18,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.18), weight: 30),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.18,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
    ]).animate(_dimensionController);
    _timerSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _dimensionController,
            curve: const Interval(0.55, 1, curve: Curves.easeOutCubic),
          ),
        );
    unawaited(_restoreFocusSession());
    _initializeNotifications();
  }

  Future<void> _restoreFocusSession() async {
    if (_isRestoringSessionInFlight || _isDisposed) return;
    _isRestoringSessionInFlight = true;
    try {
      final session = await _sessionStore.load();
      if (!mounted || _isDisposed) return;

      final endTimestampMs = session.endTimestampMs;
      var remainingSeconds = session.remainingSeconds;
      var isRunning = session.isRunning;

      if (isRunning) {
        if (endTimestampMs == null || session.sessionId == null) {
          await _sessionStore.reset(session.selectedMinutes);
          isRunning = false;
          remainingSeconds = session.selectedMinutes * 60;
        } else {
          final millisecondsLeft =
              endTimestampMs - DateTime.now().millisecondsSinceEpoch;
          remainingSeconds = millisecondsLeft <= 0
              ? 0
              : (millisecondsLeft / 1000).ceil();
        }
      }

      setState(() {
        _selectedMinutes = session.selectedMinutes;
        _remainingSeconds = remainingSeconds;
        _sessionId = session.sessionId;
        _sessionCompleted = session.completed || session.state == 'completed';
        _isRunning = isRunning && remainingSeconds > 0;
        _isSessionPaused = session.isPaused;
        _isRestoringSession = false;
      });

      if (isRunning && remainingSeconds <= 0 && session.sessionId != null) {
        _finishSession(sessionId: session.sessionId);
      } else if (_isRunning) {
        _endTime = DateTime.fromMillisecondsSinceEpoch(endTimestampMs!);
        _startTicking();
      } else if (_sessionCompleted && session.rewardPending) {
        await _completeFocusReward(session.sessionId);
      }
    } catch (error) {
      debugPrint('Could not restore saved focus session: $error');
      if (mounted) {
        setState(() {
          _isRestoringSession = false;
        });
      }
    } finally {
      _isRestoringSessionInFlight = false;
    }
  }

  Future<AudioPool?> _preparePortalSound() async {
    try {
      return await AudioPool.createFromAsset(
        path: 'audio/portal_activation.wav',
        minPlayers: 1,
        maxPlayers: 1,
        playerMode: PlayerMode.mediaPlayer,
      );
    } catch (error) {
      debugPrint('Could not prepare focus portal sound asset: $error');
      return null;
    }
  }

  Future<AudioPool?> _prepareCompletionSound() async {
    try {
      return await AudioPool.createFromAsset(
        path: 'audio/quest_complete.wav',
        minPlayers: 1,
        maxPlayers: 1,
        playerMode: PlayerMode.mediaPlayer,
      );
    } catch (error) {
      debugPrint('Could not prepare focus completion sound asset: $error');
      return null;
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      tz.initializeTimeZones();

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );

      await _notifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          if (!mounted || !context.mounted) return;

          final messenger = ScaffoldMessenger.maybeOf(context);
          if (messenger == null) return;

          messenger.showSnackBar(
            const SnackBar(
              content: Text('Welcome back! Your focus quest is waiting.'),
            ),
          );
        },
      );

      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      final granted = await android?.requestNotificationsPermission();

      if (!mounted) return;

      setState(() {
        _notificationsReady = true;
        _notificationPermissionGranted = granted ?? false;
      });
    } catch (error) {
      debugPrint('Notification initialization failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_restoreFocusSession());

      if (_guardEnabled) {
        _handleAppReturn();
      }
    } else if (state == AppLifecycleState.paused) {
      if (_isTransitioning) {
        _dimensionController.stop();
        _stopPortalSound();
        if (mounted) {
          setState(() {
            _isTransitioning = false;
          });
        }
      }

      if (_guardEnabled &&
          _isRunning &&
          _notificationsReady &&
          _notificationPermissionGranted) {
        _scheduleDistractionReminder();
      }
    }
  }

  Future<void> _scheduleDistractionReminder() async {
    if (_leftAt != null || !_isRunning || !_guardEnabled) return;

    if (!_notificationsReady || !_notificationPermissionGranted) {
      debugPrint('Focus reminder skipped: notification permission missing.');
      return;
    }

    _leftAt = DateTime.now();
    _reminderShownForInterruption = false;

    try {
      await _notifications.zonedSchedule(
        id: _distractionNotificationId,
        title: '🎯 Your focus quest is waiting!',
        body: 'Come back to MAXXING and help Biscuit earn a treat.',
        scheduledDate: tz.TZDateTime.now(
          tz.local,
        ).add(const Duration(seconds: 10)),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'maxxing_distraction_guard',
            'Distraction Guard',
            channelDescription:
                'Reminders to return to an active focus session.',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'focus_distraction',
      );

      debugPrint('MAXXING focus reminder scheduled.');
    } catch (error) {
      debugPrint('Could not schedule focus reminder: $error');
    }
  }

  Future<void> _handleAppReturn() async {
    final leftAt = _leftAt;
    if (leftAt == null) return;

    _leftAt = null;

    try {
      await _notifications.cancel(id: _distractionNotificationId);
    } catch (error) {
      debugPrint('Could not cancel focus reminder: $error');
    }

    final awayDuration = DateTime.now().difference(leftAt);

    if (!mounted || !context.mounted) return;

    if (awayDuration >= const Duration(minutes: 1) &&
        !_reminderShownForInterruption &&
        _isRunning) {
      _reminderShownForInterruption = true;

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('🎯 Welcome back! Let’s finish your focus quest.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  int _secondsUntil(DateTime end) {
    final milliseconds = end.difference(DateTime.now()).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds / 1000).ceil();
  }

  void _tick() {
    final end = _endTime;
    if (!mounted || !_isRunning || end == null) return;

    final secondsLeft = _secondsUntil(end);

    if (secondsLeft <= 0) {
      _finishSession();
    } else if (secondsLeft != _remainingSeconds) {
      setState(() => _remainingSeconds = secondsLeft);
    }
  }

  Future<void> _startTimer({required bool newSession}) async {
    if (_isRunning ||
        _isCompletingSession ||
        _isPersistingSession ||
        _isRestoringSession) {
      return;
    }

    final remainingSeconds = _remainingSeconds <= 0
        ? _totalSeconds
        : _remainingSeconds;
    final sessionId = newSession
        ? _createSessionId()
        : _sessionId ?? _createSessionId();
    final endTime = DateTime.now().add(Duration(seconds: remainingSeconds));
    setState(() {
      _isPersistingSession = true;
    });

    try {
      await _sessionStore.save(
        FocusSessionSnapshot(
          state: 'running',
          selectedMinutes: _selectedMinutes,
          remainingSeconds: remainingSeconds,
          endTimestampMs: endTime.millisecondsSinceEpoch,
          sessionId: sessionId,
          completed: false,
          rewarded: false,
          rewardPending: false,
          rewardBaseTreats: null,
        ),
      );
    } catch (error) {
      debugPrint('Could not save focus session start: $error');
      if (mounted) {
        setState(() {
          _isPersistingSession = false;
          _isTransitioning = false;
        });
      }
      return;
    }

    if (!mounted) return;
    _timer?.cancel();
    _endTime = endTime;
    _sessionId = sessionId;
    setState(() {
      _isRunning = true;
      _isSessionPaused = false;
      _sessionCompleted = false;
      _isTransitioning = false;
      _isPersistingSession = false;
      _remainingSeconds = remainingSeconds;
    });

    _startTicking();
  }

  String _createSessionId() {
    final randomPart = math.Random.secure().nextInt(0x7fffffff);
    return '${DateTime.now().microsecondsSinceEpoch}-$randomPart';
  }

  void _startTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _startOrResumeQuest() {
    if (_isRunning ||
        _isTransitioning ||
        _isCompletingSession ||
        _isRestoringSession ||
        _isPersistingSession) {
      return;
    }

    if (_isPaused) {
      unawaited(_startTimer(newSession: false));
      return;
    }

    _timer?.cancel();
    _timer = null;
    _endTime = null;
    _dimensionController
      ..stop()
      ..value = 0;

    setState(() {
      if (_sessionCompleted || _remainingSeconds <= 0) {
        _remainingSeconds = _totalSeconds;
      }
      _isTransitioning = true;
      _sessionCompleted = false;
    });
    _playPortalSound();
    unawaited(_playDimensionTransition());
  }

  Future<void> _playDimensionTransition() async {
    try {
      await _dimensionController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }

    if (!mounted || !_isTransitioning) return;

    setState(() {
      _isTransitioning = false;
    });
    await _startTimer(newSession: true);
  }

  void _playPortalSound() {
    if (_isDisposed) return;
    final requestId = ++_portalSoundRequestId;
    _portalSoundQueue = _portalSoundQueue.then(
      (_) => _startPortalSound(requestId),
    );
    unawaited(_portalSoundQueue);
  }

  void _playCompletionSound() {
    if (_isDisposed) return;
    final requestId = ++_portalSoundRequestId;
    _portalSoundQueue = _portalSoundQueue.then(
      (_) => _startCompletionSound(requestId),
    );
    unawaited(_portalSoundQueue);
  }

  Future<void> _startPortalSound(int requestId) async {
    if (_isDisposed || requestId != _portalSoundRequestId) return;
    try {
      final onStartSound = widget.onStartSound;
      if (onStartSound != null) {
        await onStartSound();
        return;
      }

      final pool = _portalAudioPool ??= _preparePortalSound();
      final resolvedPool = await pool;
      if (resolvedPool == null) {
        debugPrint(
          'Focus portal sound is unavailable; audio pool did not initialize.',
        );
        return;
      }
      if (_isDisposed || requestId != _portalSoundRequestId) return;

      final previousStop = _activePortalSoundStop;
      _activePortalSoundStop = null;
      await previousStop?.call();
      if (_isDisposed || requestId != _portalSoundRequestId) return;

      final stop = await resolvedPool.start(volume: 0.85);
      if (_isDisposed || requestId != _portalSoundRequestId) {
        await stop();
      } else {
        _activePortalSoundStop = stop;
        debugPrint('Focus portal sound started.');
      }
    } catch (error) {
      debugPrint('Could not play focus portal sound: $error');
    }
  }

  Future<void> _startCompletionSound(int requestId) async {
    if (_isDisposed || requestId != _portalSoundRequestId) return;
    try {
      final onCompleteSound = widget.onCompleteSound;
      if (onCompleteSound != null) {
        await onCompleteSound();
        return;
      }

      final completionPool = _completionAudioPool ??= _prepareCompletionSound();
      final pool = await completionPool;
      if (pool == null) {
        debugPrint(
          'Focus completion sound is unavailable; audio pool did not initialize.',
        );
        return;
      }
      if (_isDisposed || requestId != _portalSoundRequestId) return;

      final previousStop = _activePortalSoundStop;
      _activePortalSoundStop = null;
      await previousStop?.call();
      if (_isDisposed || requestId != _portalSoundRequestId) return;

      final stop = await pool.start(volume: 0.95);
      if (_isDisposed || requestId != _portalSoundRequestId) {
        await stop();
      } else {
        _activePortalSoundStop = stop;
        debugPrint('Focus completion sound started.');
      }
    } catch (error) {
      debugPrint('Could not play focus completion sound: $error');
    }
  }

  void _stopPortalSound() {
    _portalSoundRequestId++;
    _portalSoundQueue = _portalSoundQueue.then((_) async {
      final stop = _activePortalSoundStop;
      _activePortalSoundStop = null;
      try {
        await stop?.call();
      } catch (error) {
        debugPrint('Could not stop focus portal sound: $error');
      }
    });
    unawaited(_portalSoundQueue);
  }

  Future<void> _pauseTimer() async {
    if (!_isRunning || _isPersistingSession) return;

    final end = _endTime;
    final secondsLeft = end == null ? _remainingSeconds : _secondsUntil(end);

    if (secondsLeft <= 0) {
      _finishSession();
      return;
    }

    setState(() {
      _isPersistingSession = true;
    });

    _timer?.cancel();
    _timer = null;
    _endTime = null;
    try {
      await _sessionStore.save(
        FocusSessionSnapshot(
          state: 'paused',
          selectedMinutes: _selectedMinutes,
          remainingSeconds: secondsLeft,
          endTimestampMs: null,
          sessionId: _sessionId,
          completed: false,
          rewarded: false,
          rewardPending: false,
          rewardBaseTreats: null,
        ),
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _isSessionPaused = true;
        _remainingSeconds = secondsLeft;
        _isPersistingSession = false;
      });
    } catch (error) {
      debugPrint('Could not persist paused focus session: $error');
      if (!mounted) return;
      final resumedEnd = DateTime.now().add(Duration(seconds: secondsLeft));
      setState(() {
        _isRunning = true;
        _isSessionPaused = false;
        _remainingSeconds = secondsLeft;
        _endTime = resumedEnd;
        _isPersistingSession = false;
      });
      _startTicking();
    }

    _cancelDistractionReminder();
  }

  Future<void> _resetTimer() async {
    if (_isCompletingSession || _isPersistingSession) return;
    final resetDuration = _selectedMinutes;

    if (_isTransitioning) {
      _stopPortalSound();
    }
    _dimensionController
      ..stop()
      ..value = 0;
    _timer?.cancel();
    _timer = null;
    _endTime = null;

    setState(() {
      _isPersistingSession = true;
      _isRunning = false;
      _isSessionPaused = false;
      _isTransitioning = false;
      _sessionCompleted = false;
      _remainingSeconds = _totalSeconds;
      _sessionId = null;
    });

    try {
      await _sessionStore.reset(resetDuration);
    } catch (error) {
      debugPrint('Could not reset persisted focus session: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isPersistingSession = false;
        });
      }
    }
    _cancelDistractionReminder();
  }

  Future<void> _selectDuration(int minutes) async {
    if (_isRunning ||
        _isTransitioning ||
        _isCompletingSession ||
        _isPersistingSession ||
        _isRestoringSession) {
      return;
    }

    _timer?.cancel();
    _timer = null;
    _endTime = null;

    setState(() {
      _isPersistingSession = true;
      _selectedMinutes = minutes;
      _remainingSeconds = minutes * 60;
      _isRunning = false;
      _isSessionPaused = false;
      _sessionCompleted = false;
      _sessionId = null;
    });

    try {
      await _sessionStore.reset(minutes);
    } catch (error) {
      debugPrint('Could not persist selected focus duration: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isPersistingSession = false;
        });
      }
    }
    _cancelDistractionReminder();
  }

  Future<void> _showCustomDurationDialog() async {
    if (_isRunning ||
        _isTransitioning ||
        _isCompletingSession ||
        _isPersistingSession ||
        _isRestoringSession) {
      return;
    }

    final customMinutes = await showDialog<int>(
      context: context,
      builder: (_) => const _CustomDurationDialog(),
    );

    if (customMinutes != null && mounted) {
      _selectDuration(customMinutes);
    }
  }

  void _finishSession({String? sessionId}) {
    final completedSessionId = sessionId ?? _sessionId;
    if (!mounted ||
        _sessionCompleted ||
        _isCompletingSession ||
        completedSessionId == null) {
      return;
    }

    _timer?.cancel();
    _timer = null;
    _endTime = null;

    setState(() {
      _remainingSeconds = 0;
      _isRunning = false;
      _isSessionPaused = false;
      _sessionCompleted = true;
      _isCompletingSession = true;
      _completedSessions++;
    });

    _playCompletionSound();
    unawaited(_completeSessionReward(completedSessionId));
    _cancelDistractionReminder();
  }

  Future<void> _completeSessionReward(String sessionId) async {
    var rewardSaved = false;
    try {
      rewardSaved = await _sessionStore.completeAndReward(sessionId);
    } catch (error) {
      debugPrint('Could not complete focus reward for $sessionId: $error');
    }
    if (!mounted) return;

    setState(() {
      _isCompletingSession = false;
    });
    if (rewardSaved) {
      _showCompletionDialog(rewardSaved: true);
    } else {
      _showCompletionDialog(rewardSaved: false);
    }
  }

  Future<void> _completeFocusReward(String? sessionId) async {
    if (sessionId == null || !mounted) return;
    setState(() {
      _isCompletingSession = true;
    });
    await _completeSessionReward(sessionId);
  }

  Future<void> _cancelDistractionReminder() async {
    _leftAt = null;

    try {
      await _notifications.cancel(id: _distractionNotificationId);
    } catch (error) {
      debugPrint('Could not cancel reminder: $error');
    }
  }

  Future<void> _toggleGuard(bool enabled) async {
    if (!enabled) {
      await _cancelDistractionReminder();
    }

    if (!mounted) return;

    setState(() {
      _guardEnabled = enabled;
    });
  }

  void _showCompletionDialog({required bool rewardSaved}) {
    if (!mounted || !context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: _mint.withValues(alpha: 0.35)),
          ),
          icon: const Icon(
            Icons.emoji_events_rounded,
            color: _purple,
            size: 48,
          ),
          title: const Text(
            'QUEST COMPLETE!',
            textAlign: TextAlign.center,
            style: TextStyle(color: _cream, fontWeight: FontWeight.w900),
          ),
          content: Text(
            rewardSaved
                ? 'You showed up and stayed focused. Biscuit earned 1 treat '
                      'because of you. Take a breath, then choose your next quest.'
                : 'You completed your focus quest, but the treat could not '
                      'be saved. Please check your device storage before '
                      'starting another quest.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _softText, height: 1.5),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: _mint,
                foregroundColor: _background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'LET’S GO!',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _isDisposed = true;
    _portalSoundRequestId++;
    _stopPortalSound();
    final portalAudioPool = _portalAudioPool;
    if (portalAudioPool != null) {
      unawaited(
        _portalSoundQueue.then((_) async {
          final pool = await portalAudioPool;
          await pool?.dispose();
        }),
      );
    }
    _dimensionController.dispose();

    // Keep scheduled reminders intact when this screen is disposed.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _cream,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _purple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: _background,
                size: 25,
              ),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MAXXING',
                  style: TextStyle(
                    color: _cream,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                Text(
                  'FOCUS QUEST',
                  style: TextStyle(
                    color: _softText,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _purple.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 17,
                    color: _coral,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$_completedSessions',
                    style: const TextStyle(
                      color: _cream,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _dimensionController,
            builder: (context, child) {
              return Transform.scale(
                scale: _isTransitioning ? _contentScale.value : 1,
                child: child,
              );
            },
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuestHeader(),
                    const SizedBox(height: 18),
                    _buildBiscuitTransitionCard(),
                    const SizedBox(height: 18),
                    _buildTimerEntry(),
                    const SizedBox(height: 16),
                    _buildDurationCard(),
                    const SizedBox(height: 16),
                    _buildRewardCard(),
                    const SizedBox(height: 16),
                    _buildDistractionGuardCard(),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        _sessionCompleted
                            ? 'NICE WORK, FOCUS CHAMPION.'
                            : 'SMALL STEPS. BIG XP. EVERY DAY.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _softText,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isTransitioning) _buildDimensionOverlay(),
        ],
      ),
    );
  }

  Widget _buildDimensionOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _dimensionController,
            builder: (context, _) {
              final portalOpacity = _portalOpacity.value;
              final portalProgress = _portalProgress.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: _portalViolet.withValues(
                      alpha: 0.18 * _roomGlowOpacity.value,
                    ),
                  ),
                  ColoredBox(
                    color: const Color(
                      0xFF090613,
                    ).withValues(alpha: 0.2 * _roomGlowOpacity.value),
                  ),
                  CustomPaint(
                    painter: _FocusPortalPainter(
                      progress: portalProgress,
                      opacity: portalOpacity,
                    ),
                  ),
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        FadeTransition(
                          opacity: _enteringTitleOpacity,
                          child: _dimensionMessage('ENTERING FOCUS DIMENSION'),
                        ),
                        FadeTransition(
                          opacity: _activatedTitleOpacity,
                          child: _dimensionMessage('FOCUS MODE ACTIVATED'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _dimensionMessage(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: _background.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _portalLavender.withValues(alpha: 0.7)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _cream,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildBiscuitTransitionCard() {
    return AnimatedBuilder(
      animation: _dimensionController,
      child: _buildBiscuitCard(),
      builder: (context, child) {
        final shieldOpacity = _isTransitioning
            ? _portalProgress.value * _portalOpacity.value
            : 0.0;
        return Transform.scale(
          scale: _isTransitioning ? _biscuitScale.value : 1,
          child: Stack(
            children: [
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _portalLavender.withValues(
                          alpha: 0.85 * shieldOpacity,
                        ),
                        width: 1.5 + 1.5 * shieldOpacity,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimerEntry() {
    return AnimatedBuilder(
      animation: _dimensionController,
      child: _buildTimerCard(),
      builder: (context, child) {
        if (!_isTransitioning) return child!;
        return FadeTransition(
          opacity: _timerOpacity,
          child: SlideTransition(position: _timerSlide, child: child),
        );
      },
    );
  }

  Widget _buildQuestHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isRunning ? 'YOU’RE IN THE ZONE' : 'READY TO LEVEL UP?',
          style: const TextStyle(
            color: _purple,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _sessionCompleted
              ? 'Quest completed!'
              : _isRunning
              ? 'Keep that streak alive.'
              : 'One quest at a time.',
          style: const TextStyle(
            color: _cream,
            fontSize: 27,
            height: 1.12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Focus on your goal. Biscuit is cheering you on.',
          style: TextStyle(color: _softText, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildBiscuitCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _coral.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: const Color(0xFF393057),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _purple.withValues(alpha: 0.25)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/biscuit.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Text('🐱', style: TextStyle(fontSize: 52)),
                );
              },
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'BISCUIT',
                      style: TextStyle(
                        color: _cream,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('✨', style: TextStyle(fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  _sessionCompleted
                      ? 'You did it! I earned a treat!'
                      : _isRunning
                      ? 'You focus. I cheer. Deal?'
                      : 'Let’s finish a quest together!',
                  style: const TextStyle(
                    color: _softText,
                    height: 1.4,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 11),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _coral.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_rounded, color: _coral, size: 13),
                      SizedBox(width: 5),
                      Text(
                        'YOUR FOCUS BUDDY',
                        style: TextStyle(
                          color: _cream,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _purple.withValues(alpha: 0.24)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isRunning
                    ? Icons.bolt_rounded
                    : Icons.hourglass_bottom_rounded,
                color: _purple,
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _purple,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 230,
                  height: 230,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.07),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _sessionCompleted ? _mint : _coral,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: _background.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _timeText,
                      style: const TextStyle(
                        color: _cream,
                        fontSize: 43,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        fontFeatures: [],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _sessionCompleted
                          ? 'COMPLETE'
                          : _isRunning
                          ? 'STAY IN THE ZONE'
                          : _isPaused
                          ? 'TAKE A BREATH'
                          : 'MINUTES FOR YOU',
                      style: const TextStyle(
                        color: _softText,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _purple.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _sessionCompleted
                            ? '+1 BISCUIT TREAT'
                            : '${(_progress * 100).round()}% COMPLETE',
                        style: const TextStyle(
                          color: _purple,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ScaleTransition(
                  scale: _buttonScale,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isCompletingSession ||
                            _isTransitioning ||
                            _isPersistingSession ||
                            _isRestoringSession
                        ? null
                        : _isRunning
                        ? _pauseTimer
                        : _startOrResumeQuest,
                    icon: Icon(
                      _isCompletingSession
                          ? Icons.hourglass_top_rounded
                          : _isRunning
                          ? Icons.pause_rounded
                          : _isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.bolt_rounded,
                    ),
                    label: Text(
                      _isCompletingSession
                          ? 'SAVING REWARD'
                          : _isRestoringSession || _isPersistingSession
                          ? 'SAVING QUEST'
                          : _isTransitioning
                          ? 'ENTERING DIMENSION'
                          : _isRunning
                          ? 'PAUSE QUEST'
                          : _isPaused
                          ? 'RESUME QUEST'
                          : 'START QUEST',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: _background,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: _background,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: IconButton(
                  onPressed:
                      _isCompletingSession ||
                          _isPersistingSession ||
                          _isRestoringSession
                      ? null
                      : _resetTimer,
                  tooltip: 'Reset timer',
                  icon: const Icon(Icons.restart_alt_rounded, color: _cream),
                  padding: const EdgeInsets.all(14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDurationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: _mint, size: 20),
              SizedBox(width: 8),
              Text(
                'CHOOSE YOUR QUEST',
                style: TextStyle(
                  color: _cream,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Pick a time that feels achievable.',
            style: TextStyle(color: _softText, fontSize: 12),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _durationButton(15),
              const SizedBox(width: 8),
              _durationButton(25),
              const SizedBox(width: 8),
              _durationButton(45),
              const SizedBox(width: 8),
              _customDurationButton(),
            ],
          ),
          if (_isRunning) ...[
            const SizedBox(height: 11),
            const Row(
              children: [
                Icon(Icons.lock_rounded, color: _softText, size: 13),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Pause the quest to change its duration.',
                    style: TextStyle(color: _softText, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRewardCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF263B39),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _mint.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 51,
            height: 51,
            decoration: BoxDecoration(
              color: _mint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.redeem_rounded, color: _mint, size: 27),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FOCUS = TREATS',
                  style: TextStyle(
                    color: _cream,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Finish a session and Biscuit earns 1 treat.',
                  style: TextStyle(
                    color: Color(0xFFD0DED8),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '+1',
            style: TextStyle(
              color: _mint,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistractionGuardCard() {
    final String description;

    if (!_notificationsReady) {
      description = 'Setting up reminders...';
    } else if (_notificationPermissionGranted) {
      description = 'A gentle nudge when you leave the app.';
    } else {
      description = 'Allow notifications for focus reminders.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _coral.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.shield_moon_rounded,
              color: _coral,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DISTRACTION GUARD',
                  style: TextStyle(
                    color: _cream,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: _softText,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                if (!_notificationPermissionGranted && _notificationsReady) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Check Android notification permission in Settings.',
                    style: TextStyle(color: _coral, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Switch.adaptive(
            value: _guardEnabled,
            activeTrackColor: _mint,
            onChanged: _toggleGuard,
          ),
        ],
      ),
    );
  }

  Widget _customDurationButton() {
    final isCustom = ![15, 25, 45].contains(_selectedMinutes);

    return Expanded(
      child: OutlinedButton(
        onPressed:
            _isRunning ||
                _isTransitioning ||
                _isCompletingSession ||
                _isPersistingSession ||
                _isRestoringSession
            ? null
            : _showCustomDurationDialog,
        style: OutlinedButton.styleFrom(
          backgroundColor: isCustom
              ? _purple.withValues(alpha: 0.13)
              : _background,
          foregroundColor: isCustom ? _purple : _softText,
          side: BorderSide(
            color: isCustom ? _purple : Colors.white.withValues(alpha: 0.08),
            width: isCustom ? 1.4 : 1,
          ),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: const Icon(Icons.add_rounded, size: 20),
      ),
    );
  }

  Widget _durationButton(int minutes) {
    final selected = _selectedMinutes == minutes;

    return Expanded(
      child: OutlinedButton(
        onPressed:
            _isRunning ||
                _isTransitioning ||
                _isCompletingSession ||
                _isPersistingSession ||
                _isRestoringSession
            ? null
            : () => _selectDuration(minutes),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? _purple : _background,
          foregroundColor: selected ? _background : _softText,
          side: BorderSide(
            color: selected ? _purple : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.4 : 1,
          ),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$minutes min',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: selected ? _background : _softText,
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusPortalPainter extends CustomPainter {
  const _FocusPortalPainter({required this.progress, required this.opacity});

  final double progress;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || opacity <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height) * 0.7;
    final portalRadius = math.max(12.0, maxRadius * progress);
    final portalBounds = Rect.fromCircle(center: center, radius: portalRadius);

    final portalPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xEE171027),
          Color(0xDD24133F),
          Color(0xC04D238D),
          Color(0xAA8B5CFF),
          Color(0x00DCCBFF),
        ],
        stops: [0, 0.48, 0.76, 0.9, 1],
      ).createShader(portalBounds)
      ..color = Colors.white.withValues(alpha: opacity);
    canvas.drawCircle(center, portalRadius, portalPaint);

    const ringColors = [
      Color(0xFFF0E8FF),
      Color(0xFFC09AFF),
      Color(0xFF8A4DFF),
      Color(0xFFFFD66B),
    ];
    for (var ring = 0; ring < ringColors.length; ring++) {
      final ringProgress = (progress - ring * 0.1).clamp(0.0, 1.0);
      if (ringProgress <= 0) continue;

      final radiusFactor = 1 - ring * 0.075;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring == 0
            ? 5
            : ring == 1
            ? 3.5
            : 2.5
        ..color = ringColors[ring].withValues(
          alpha: opacity * (ring == 0 ? 0.95 : 0.75),
        );
      canvas.drawCircle(center, maxRadius * ringProgress * radiusFactor, paint);

      if (ring < 3) {
        final arcPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.square
          ..strokeWidth = 5
          ..color = ringColors[ring].withValues(alpha: opacity * 0.9);
        canvas.drawArc(
          Rect.fromCircle(
            center: center,
            radius: maxRadius * ringProgress * (0.72 + ring * 0.07),
          ),
          ring * 0.9,
          math.pi * 0.65,
          false,
          arcPaint,
        );
      }
    }

    const particleColors = [
      Color(0xFFF0E8FF),
      Color(0xFFC09AFF),
      Color(0xFF8A4DFF),
      Color(0xFFFFD66B),
    ];
    for (var particle = 0; particle < 32; particle++) {
      final startOffset = (particle % 8) * 0.025;
      final particleProgress = ((progress - startOffset) / (1 - startOffset))
          .clamp(0.0, 1.0);
      if (particleProgress <= 0) continue;

      final angle = particle * math.pi * 2 / 32;
      final distance =
          maxRadius *
          (0.22 + particleProgress * 0.78) *
          (0.58 + (particle % 5) * 0.09);
      final point = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      final particleSize = 3.5 + (particle % 4) * 1.2;
      final paint = Paint()
        ..color = particleColors[particle % particleColors.length].withValues(
          alpha: opacity * (0.98 - particleProgress * 0.2),
        );
      canvas.drawRect(
        Rect.fromCenter(
          center: point,
          width: particleSize,
          height: particleSize,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FocusPortalPainter oldDelegate) {
    return progress != oldDelegate.progress || opacity != oldDelegate.opacity;
  }
}
