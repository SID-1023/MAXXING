import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  static const Color _background = Color(0xFF09090F);
  static const Color _purple = Color(0xFFB69CFF);
  static const Color _card = Color(0xFF151520);

  static const int _distractionNotificationId = 707;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Timer? _timer;
  DateTime? _endTime;
  DateTime? _leftAt;

  int _selectedMinutes = 25;
  int _remainingSeconds = 25 * 60;
  int _completedSessions = 0;

  bool _isRunning = false;
  bool _sessionCompleted = false;
  bool _guardEnabled = true;
  bool _notificationsReady = false;
  bool _notificationPermissionGranted = false;
  bool _reminderShownForInterruption = false;

  int get _totalSeconds => _selectedMinutes * 60;

  double get _progress {
    if (_totalSeconds == 0) return 0;
    return (1 - (_remainingSeconds / _totalSeconds)).clamp(0.0, 1.0);
  }

  String get _timeText {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNotifications();
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
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome back! Your focus goal is waiting.'),
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
    if (!_guardEnabled || !_isRunning) return;

    if (state == AppLifecycleState.paused) {
      // Schedule the reminder as soon as the app goes to background.
      // Do not wait for the app to be closed or terminated.
      if (_notificationsReady && _notificationPermissionGranted) {
        _scheduleDistractionReminder();
      }
    } else if (state == AppLifecycleState.resumed) {
      _handleAppReturn();
      _refreshTimerAfterReturn();
    }
  }

  Future<void> _scheduleDistractionReminder() async {
    if (_leftAt != null || !_isRunning || !_guardEnabled) return;

    if (!_notificationsReady || !_notificationPermissionGranted) {
      debugPrint('Focus reminder skipped: notification permission missing.');
      return;
    }

    // Record the time the user left.
    _leftAt = DateTime.now();
    _reminderShownForInterruption = false;

    try {
      await _notifications.zonedSchedule(
        id: _distractionNotificationId,
        title: '🎯 Stay focused!',
        body: 'Your goal is waiting. Return to MAXXING.',
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
      // Cancel the pending reminder when the user returns.
      await _notifications.cancel(id: _distractionNotificationId);
    } catch (error) {
      debugPrint('Could not cancel focus reminder: $error');
    }

    final awayDuration = DateTime.now().difference(leftAt);

    if (!mounted) return;

    if (awayDuration >= const Duration(minutes: 1) &&
        !_reminderShownForInterruption &&
        _isRunning) {
      _reminderShownForInterruption = true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎯 Back on track! Let’s finish your focus session.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _refreshTimerAfterReturn() {
    final endTime = _endTime;

    if (!_isRunning || endTime == null) return;

    final secondsLeft = endTime.difference(DateTime.now()).inSeconds;

    if (secondsLeft <= 0) {
      _finishSession();
    } else if (mounted) {
      setState(() {
        _remainingSeconds = secondsLeft;
      });
    }
  }

  void _startTimer() {
    if (_isRunning) return;

    if (_remainingSeconds <= 0) {
      _remainingSeconds = _totalSeconds;
    }

    _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));

    setState(() {
      _isRunning = true;
      _sessionCompleted = false;
    });

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRunning || _endTime == null) return;

      final secondsLeft = _endTime!.difference(DateTime.now()).inSeconds;

      if (secondsLeft <= 0) {
        _finishSession();
      } else {
        setState(() {
          _remainingSeconds = secondsLeft;
        });
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _endTime = null;

    setState(() {
      _isRunning = false;
    });

    _cancelDistractionReminder();
  }

  void _resetTimer() {
    _timer?.cancel();
    _endTime = null;

    setState(() {
      _isRunning = false;
      _sessionCompleted = false;
      _remainingSeconds = _totalSeconds;
    });

    _cancelDistractionReminder();
  }

  void _selectDuration(int minutes) {
    if (_isRunning) return;

    _timer?.cancel();
    _endTime = null;

    setState(() {
      _selectedMinutes = minutes;
      _remainingSeconds = minutes * 60;
      _isRunning = false;
      _sessionCompleted = false;
    });

    _cancelDistractionReminder();
  }

  void _finishSession() {
    _timer?.cancel();
    _endTime = null;

    if (!mounted) return;

    setState(() {
      _remainingSeconds = 0;
      _isRunning = false;
      _sessionCompleted = true;
      _completedSessions++;
    });

    _cancelDistractionReminder();
    _showCompletionDialog();
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

  void _showCompletionDialog() {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Session complete! 🎉',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Great work. Take a breath before your next session.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Nice!', style: TextStyle(color: _purple)),
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

    // IMPORTANT:
    // Do not cancel the scheduled notification here.
    // The reminder must survive when this screen is disposed.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Focus Mode',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _purple.withValues(alpha: 0.18)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.self_improvement_rounded,
                      color: _purple,
                      size: 38,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'One thing at a time.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Silence the noise. Focus on your growth.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 28),
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
                              strokeWidth: 9,
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                _purple,
                              ),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _timeText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _sessionCompleted
                                    ? 'COMPLETED'
                                    : _isRunning
                                    ? 'STAY FOCUSED'
                                    : 'READY TO FOCUS',
                                style: const TextStyle(
                                  color: _purple,
                                  letterSpacing: 1.5,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Choose duration',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _durationButton(15),
                        const SizedBox(width: 10),
                        _durationButton(25),
                        const SizedBox(width: 10),
                        _durationButton(45),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isRunning ? _pauseTimer : _startTimer,
                            icon: Icon(
                              _isRunning
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            label: Text(_isRunning ? 'Pause' : 'Start Focus'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _purple,
                              foregroundColor: _background,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _resetTimer,
                          tooltip: 'Reset timer',
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white10,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Distraction Guard
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        color: _purple,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Distraction Guard',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            !_notificationsReady
                                ? 'Setting up notifications...'
                                : _notificationPermissionGranted
                                ? 'Remind me if I leave for 1 minute'
                                : 'Allow notifications for reminders',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _guardEnabled,
                      activeTrackColor: _purple,
                      onChanged: _toggleGuard,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: _purple,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Completed sessions',
                            style: TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_completedSessions',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Small steps every day lead to big changes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _durationButton(int minutes) {
    final selected = _selectedMinutes == minutes;

    return Expanded(
      child: OutlinedButton(
        onPressed: _isRunning ? null : () => _selectDuration(minutes),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? _purple.withValues(alpha: 0.15)
              : Colors.transparent,
          foregroundColor: selected ? _purple : Colors.white70,
          side: BorderSide(color: selected ? _purple : Colors.white12),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text('$minutes min'),
      ),
    );
  }
}
