import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
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

  bool get _isPaused =>
      !_isRunning &&
      !_sessionCompleted &&
      _remainingSeconds > 0 &&
      _remainingSeconds < _totalSeconds;

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
      // Resync the clock whenever the app returns to the foreground.
      _tick();

      if (_guardEnabled) {
        _handleAppReturn();
      }
    } else if (state == AppLifecycleState.paused) {
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
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _pauseTimer() {
    if (!_isRunning) return;

    final end = _endTime;

    _timer?.cancel();
    _timer = null;
    _endTime = null;

    final secondsLeft = end == null ? _remainingSeconds : _secondsUntil(end);

    if (secondsLeft <= 0) {
      _finishSession();
      return;
    }

    setState(() {
      _isRunning = false;
      _remainingSeconds = secondsLeft;
    });

    _cancelDistractionReminder();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = null;
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
    _timer = null;
    _endTime = null;

    setState(() {
      _selectedMinutes = minutes;
      _remainingSeconds = minutes * 60;
      _isRunning = false;
      _sessionCompleted = false;
    });

    _cancelDistractionReminder();
  }

  Future<void> _showCustomDurationDialog() async {
    if (_isRunning) return;

    final customMinutes = await showDialog<int>(
      context: context,
      builder: (_) => const _CustomDurationDialog(),
    );

    if (customMinutes != null && mounted) {
      _selectDuration(customMinutes);
    }
  }

  Future<void> _rewardBiscuitForFocus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentTreats = prefs.getInt('biscuit_treats') ?? 5;

      await prefs.setInt('biscuit_treats', currentTreats + 1);

      debugPrint('Biscuit earned 1 treat for a completed focus session.');
    } catch (error) {
      debugPrint('Could not save Biscuit focus reward: $error');
    }
  }

  void _finishSession() {
    if (!mounted || _sessionCompleted) return;

    _timer?.cancel();
    _timer = null;
    _endTime = null;

    setState(() {
      _remainingSeconds = 0;
      _isRunning = false;
      _sessionCompleted = true;
      _completedSessions++;
    });

    _rewardBiscuitForFocus();
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
          content: const Text(
            'You showed up and stayed focused. Biscuit earned 1 treat '
            'because of you. Take a breath, then choose your next quest.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _softText, height: 1.5),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuestHeader(),
              const SizedBox(height: 18),
              _buildBiscuitCard(),
              const SizedBox(height: 18),
              _buildTimerCard(),
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
                child: ElevatedButton.icon(
                  onPressed: _isRunning ? _pauseTimer : _startTimer,
                  icon: Icon(
                    _isRunning
                        ? Icons.pause_rounded
                        : _isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.bolt_rounded,
                  ),
                  label: Text(
                    _isRunning
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
                  onPressed: _resetTimer,
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
        onPressed: _isRunning ? null : _showCustomDurationDialog,
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
        onPressed: _isRunning ? null : () => _selectDuration(minutes),
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
