import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/focus_session_store.dart';
import 'task_screens.dart';
import 'progress_screen.dart';
import 'focus_screen.dart';
import 'study_buddy.dart';
import 'distraction_blocker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const Color _background = Color(0xFF17132B);
  static const Color _panel = Color(0xFF241D42);
  static const Color _cream = Color(0xFFF6EFE3);
  static const Color _coral = Color(0xFFFF8A65);
  static const Color _yellow = Color(0xFFFFD66B);
  static const Color _mint = Color(0xFF7ED9B0);
  static const Color _muted = Color(0xFFB9B1D0);

  static const String _happinessKey = 'biscuit_happiness';
  static const String _treatsKey = 'biscuit_treats';
  static const String _energyKey = 'biscuit_energy';
  static const String _energyDecayAnchorKey = 'biscuit_energy_decay_anchor_ms';
  static const String _happinessDecayAnchorKey =
      'biscuit_happiness_decay_anchor_ms';
  static const int _energyDecayIntervalMs = 10 * 60 * 1000;
  static const int _happinessDecayIntervalMs = 20 * 60 * 1000;

  final FocusSessionStore _focusSessionStore = FocusSessionStore();
  bool _biscuitIsBlinking = false;
  bool _isLoadingStats = true;
  bool _isUpdatingStats = false;

  int _biscuitHappiness = 90;
  int _biscuitEnergy = 100;
  int _biscuitTreats = 5;

  String _biscuitMessage = 'Ready to make today count?';

  Timer? _biscuitBlinkTimer;
  Timer? _biscuitBlinkOffTimer;
  Timer? _statsRefreshTimer;
  Future<void>? _statsRefreshInFlight;
  Future<void>? _focusRecoveryInFlight;

  // Time-based scene state
  String _denSceneAsset = 'assets/images/den_scene.png';
  Timer? _denSceneTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _denSceneAsset = _getDenSceneForTime(DateTime.now());

    _refreshBiscuitStats();
    _startBiscuitBlinking();
    _statsRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshBiscuitStats(),
    );

    // Check the time every minute to see if we need to crossfade to a new background.
    _denSceneTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshDenScene(),
    );
  }

  String _getDenSceneForTime(DateTime time) {
    final hour = time.hour;

    // Morning: 5:00 AM to 10:59 AM
    if (hour >= 5 && hour < 11) {
      return 'assets/images/den_scene_morning.png';
    }

    // Afternoon: 11:00 AM to 3:59 PM
    if (hour >= 11 && hour < 16) {
      return 'assets/images/den_scene_afternoon.png';
    }

    // Evening: 4:00 PM to 6:59 PM
    if (hour >= 16 && hour < 19) {
      return 'assets/images/den_scene_evening.png';
    }

    // Night: 7:00 PM to 4:59 AM
    return 'assets/images/den_scene.png';
  }

  void _refreshDenScene() {
    if (!mounted) return;

    final nextScene = _getDenSceneForTime(DateTime.now());

    if (nextScene != _denSceneAsset) {
      setState(() {
        _denSceneAsset = nextScene;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshBiscuitStats();
    }
  }

  int _readBoundedInt(
    SharedPreferences prefs,
    String key,
    int fallback,
    int maximum,
  ) {
    final value = prefs.get(key);
    return value is int ? value.clamp(0, maximum) : fallback;
  }

  Future<void> _refreshBiscuitStats() {
    if (_isUpdatingStats) return Future<void>.value();
    final inFlight = _statsRefreshInFlight;
    if (inFlight != null) return inFlight;

    final refresh = _performStatsRefresh();
    _statsRefreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_statsRefreshInFlight, refresh)) {
        _statsRefreshInFlight = null;
      }
    });
  }

  Future<void> _performStatsRefresh() async {
    try {
      await _recoverExpiredFocusSession();
      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final storedEnergy = prefs.get(_energyKey);
      final storedHappiness = prefs.get(_happinessKey);
      final energy = storedEnergy is int ? storedEnergy.clamp(0, 100) : 100;
      final happiness = storedHappiness is int
          ? storedHappiness.clamp(0, 100)
          : 90;
      final treats = _readBoundedInt(prefs, _treatsKey, 5, 999);

      final energyAnchor = _decayStat(
        prefs,
        anchorKey: _energyDecayAnchorKey,
        value: energy,
        intervalMs: _energyDecayIntervalMs,
        nowMs: nowMs,
      );
      final happinessAnchor = _decayStat(
        prefs,
        anchorKey: _happinessDecayAnchorKey,
        value: happiness,
        intervalMs: _happinessDecayIntervalMs,
        nowMs: nowMs,
      );
      final updatedEnergy = energyAnchor.value;
      final updatedHappiness = happinessAnchor.value;

      await _writeIntIfChanged(prefs, _energyKey, updatedEnergy);
      await _writeIntIfChanged(prefs, _happinessKey, updatedHappiness);
      await _writeIntIfChanged(
        prefs,
        _energyDecayAnchorKey,
        energyAnchor.anchorMs,
      );
      await _writeIntIfChanged(
        prefs,
        _happinessDecayAnchorKey,
        happinessAnchor.anchorMs,
      );
      await _writeIntIfChanged(prefs, _treatsKey, treats);

      if (!mounted) return;

      if (_biscuitHappiness != updatedHappiness ||
          _biscuitEnergy != updatedEnergy ||
          _biscuitTreats != treats ||
          _isLoadingStats) {
        setState(() {
          _biscuitHappiness = updatedHappiness;
          _biscuitEnergy = updatedEnergy;
          _biscuitTreats = treats;
          _isLoadingStats = false;
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingStats = false;
      });

      debugPrint('Could not load Biscuit stats: $error');
    }
  }

  Future<void> _recoverExpiredFocusSession() {
    final inFlight = _focusRecoveryInFlight;
    if (inFlight != null) return inFlight;

    final recovery = _performFocusSessionRecovery();
    _focusRecoveryInFlight = recovery;
    return recovery.whenComplete(() {
      if (identical(_focusRecoveryInFlight, recovery)) {
        _focusRecoveryInFlight = null;
      }
    });
  }

  Future<void> _performFocusSessionRecovery() async {
    try {
      final session = await _focusSessionStore.load();
      final sessionId = session.sessionId;
      final endTimestampMs = session.endTimestampMs;
      final isExpiredRunningSession =
          session.isRunning &&
          endTimestampMs != null &&
          endTimestampMs <= DateTime.now().millisecondsSinceEpoch;
      final hasPendingReward =
          session.state == 'completed' && session.rewardPending;
      if (sessionId == null ||
          (!isExpiredRunningSession && !hasPendingReward)) {
        return;
      }

      await _focusSessionStore.completeAndReward(sessionId);
    } catch (error) {
      debugPrint('Could not recover expired focus session: $error');
    }
  }

  ({int value, int anchorMs}) _decayStat(
    SharedPreferences prefs, {
    required String anchorKey,
    required int value,
    required int intervalMs,
    required int nowMs,
  }) {
    final storedAnchor = prefs.get(anchorKey);
    if (storedAnchor is! int || storedAnchor <= 0 || storedAnchor > nowMs) {
      return (value: value, anchorMs: nowMs);
    }

    final elapsedMs = nowMs - storedAnchor;
    final elapsedIntervals = elapsedMs ~/ intervalMs;
    if (elapsedIntervals == 0) {
      return (value: value, anchorMs: storedAnchor);
    }

    final nextValue = (value - elapsedIntervals).clamp(0, 100);
    return (
      value: nextValue,
      anchorMs: storedAnchor + elapsedIntervals * intervalMs,
    );
  }

  Future<void> _writeIntIfChanged(
    SharedPreferences prefs,
    String key,
    int value,
  ) async {
    if (prefs.get(key) != value) {
      final saved = await prefs.setInt(key, value);
      if (!saved) {
        throw StateError('SharedPreferences did not save $key.');
      }
    }
  }

  // Biscuit blinks approximately every three seconds.
  void _startBiscuitBlinking() {
    _biscuitBlinkTimer?.cancel();
    _biscuitBlinkTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      setState(() {
        _biscuitIsBlinking = true;
      });

      _biscuitBlinkOffTimer?.cancel();
      _biscuitBlinkOffTimer = Timer(const Duration(milliseconds: 180), () {
        if (!mounted) return;

        setState(() {
          _biscuitIsBlinking = false;
        });

        _startBiscuitBlinking();
      });
    });
  }

  Future<void> _petBiscuit() async {
    if (_isLoadingStats || _isUpdatingStats) return;
    await _refreshBiscuitStats();
    if (!mounted || _isUpdatingStats) return;

    setState(() {
      _isUpdatingStats = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final happiness = (_biscuitHappiness + 3).clamp(0, 100);
      await _writeIntIfChanged(prefs, _happinessKey, happiness);

      if (!mounted) return;
      setState(() {
        _biscuitHappiness = happiness;
        _biscuitMessage = happiness >= 100
            ? 'I am the happiest kitty! ❤️'
            : 'Purr... I love that! ❤️';
      });
    } catch (error) {
      debugPrint('Could not save Biscuit pet interaction: $error');
      if (mounted) {
        setState(() {
          _biscuitMessage = 'I could not save that just now. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStats = false;
        });
      } else {
        _isUpdatingStats = false;
      }
    }
  }

  Future<void> _feedBiscuit() async {
    if (_isLoadingStats || _isUpdatingStats) return;
    await _refreshBiscuitStats();
    if (!mounted || _isUpdatingStats) return;

    setState(() {
      _isUpdatingStats = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final treats = _readBoundedInt(prefs, _treatsKey, _biscuitTreats, 999);
      if (treats <= 0) {
        if (mounted) {
          setState(() {
            _biscuitMessage =
                'Biscuit needs a treat earned through Focus Mode. 🐾';
            _biscuitTreats = 0;
          });
        }
        return;
      }

      final energy = (_biscuitEnergy + 35).clamp(0, 100);
      final happiness = (_biscuitHappiness + 15).clamp(0, 100);
      final remainingTreats = treats - 1;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      await _writeIntIfChanged(prefs, _energyKey, energy);
      await _writeIntIfChanged(prefs, _happinessKey, happiness);
      await _writeIntIfChanged(prefs, _energyDecayAnchorKey, nowMs);
      await _writeIntIfChanged(prefs, _happinessDecayAnchorKey, nowMs);
      await _writeIntIfChanged(prefs, _treatsKey, remainingTreats);

      if (!mounted) return;
      setState(() {
        _biscuitEnergy = energy;
        _biscuitHappiness = happiness;
        _biscuitTreats = remainingTreats;
        _biscuitMessage = 'Yummy! Thank you for the treat! 😻';
      });
    } catch (error) {
      debugPrint('Could not save Biscuit feeding: $error');
      if (mounted) {
        setState(() {
          _biscuitMessage =
              'I could not save the treat just now. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStats = false;
        });
      } else {
        _isUpdatingStats = false;
      }
    }
  }

  Future<void> _openScreen(BuildContext context, Widget screen) async {
    final Route<void> route;
    if (screen is FocusScreen) {
      route = PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, _, _) => screen,
        transitionsBuilder: (context, animation, _, child) {
          final transition = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: transition,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.035),
                end: Offset.zero,
              ).animate(transition),
              child: child,
            ),
          );
        },
      );
    } else {
      route = MaterialPageRoute<void>(builder: (_) => screen);
    }

    await Navigator.of(context).push<void>(route);
    if (mounted) {
      await _refreshBiscuitStats();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _biscuitBlinkTimer?.cancel();
    _biscuitBlinkOffTimer?.cancel();
    _denSceneTimer?.cancel();
    _statsRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // MAXXING header.
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.pets_rounded,
                      color: _yellow,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MAXXING',
                          style: TextStyle(
                            color: _cream,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          'YOUR LITTLE CORNER OF FOCUS',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 9,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statChip(Icons.monetization_on_rounded, '120', _yellow),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                'Your Den',
                style: TextStyle(
                  color: _cream,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'A cozy space to grow, one day at a time.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),

              const SizedBox(height: 18),

              // Den background and interactive Biscuit.
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 285,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Time-based animated background
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 1000),
                          switchInCurve: Curves.easeInOut,
                          switchOutCurve: Curves.easeInOut,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          child: Image.asset(
                            _denSceneAsset,
                            key: ValueKey<String>(_denSceneAsset),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/images/den_scene.png',
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorBuilder: (context, err, stack) {
                                  return Container(
                                    color: _panel,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.all(20),
                                    child: const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.image_not_supported_outlined,
                                          color: _yellow,
                                          size: 36,
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          'Den artwork not found',
                                          style: TextStyle(color: _cream),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'Check assets/images/den_scene.png',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),

                      // Dark gradient overlay.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x22000000),
                              Color(0x00000000),
                              Color(0x55000000),
                            ],
                          ),
                        ),
                      ),

                      // Biscuit's speech bubble, cat and name.
                      // Keep bottom: 35 so Biscuit stays on the carpet.
                      Positioned(
                        bottom: 35,
                        left: 25,
                        right: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              constraints: const BoxConstraints(maxWidth: 245),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: _cream,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _biscuitMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _background,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Tap Biscuit to pet her.
                            GestureDetector(
                              onTap: _petBiscuit,
                              child: SizedBox(
                                width: 100,
                                height: 85,
                                child: Image.asset(
                                  _biscuitIsBlinking
                                      ? 'assets/images/biscuit_blink.png'
                                      : 'assets/images/biscuit.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.none,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.pets_rounded,
                                      color: _coral,
                                      size: 60,
                                    );
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 2),

                            const Text(
                              'BISCUIT',
                              style: TextStyle(
                                color: _cream,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 5),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Room label.
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _background.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.nightlight_round,
                                size: 14,
                                color: _yellow,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'HOME SWEET HOME',
                                style: TextStyle(
                                  color: _cream,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Interactive pet actions.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingStats || _isUpdatingStats
                          ? null
                          : _petBiscuit,
                      icon: const Icon(Icons.favorite_rounded),
                      label: const Text('Pet Biscuit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _coral,
                        side: const BorderSide(color: _coral),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingStats || _isUpdatingStats
                          ? null
                          : _feedBiscuit,
                      icon: const Icon(Icons.restaurant_rounded),
                      label: Text(
                        _isLoadingStats
                            ? 'Loading...'
                            : _isUpdatingStats
                            ? 'Saving...'
                            : 'Feed ($_biscuitTreats)',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _yellow,
                        foregroundColor: _background,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Biscuit's live status.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF51466F)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Biscuit's mood",
                            style: TextStyle(
                              color: _cream,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.favorite_rounded,
                          color: _coral,
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _biscuitEnergy < 25
                              ? 'Low energy'
                              : _biscuitHappiness < 25
                              ? 'Needs love'
                              : _biscuitHappiness >= 100
                              ? 'Overjoyed'
                              : _biscuitHappiness >= 70
                              ? 'Happy'
                              : _biscuitHappiness >= 40
                              ? 'Content'
                              : 'Needs love',
                          style: const TextStyle(
                            color: _mint,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    _statusBar('Energy', _biscuitEnergy / 100.0, _yellow),

                    const SizedBox(height: 12),

                    _statusBar('Happiness', _biscuitHappiness / 100, _mint),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        const Icon(
                          Icons.restaurant_rounded,
                          color: _yellow,
                          size: 17,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Treats remaining: $_biscuitTreats',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Daily quest.
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "TODAY'S QUEST",
                      style: TextStyle(
                        color: _cream,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                  const Text(
                    '0 / 1 COMPLETE',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _menuCard(
                icon: Icons.timer_rounded,
                iconColor: _yellow,
                title: 'Complete a focus session',
                subtitle: 'Help Biscuit earn some treats.',
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: _muted,
                  size: 16,
                ),
                onTap: () => _openScreen(context, const FocusScreen()),
              ),

              const SizedBox(height: 24),

              const Text(
                'YOUR WORKSPACE',
                style: TextStyle(
                  color: _cream,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _menuCard(
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: _mint,
                      title: 'Tasks',
                      subtitle: 'Plan your day',
                      onTap: () => _openScreen(context, const TasksScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _menuCard(
                      icon: Icons.insights_rounded,
                      iconColor: _yellow,
                      title: 'Progress',
                      subtitle: 'Track growth',
                      onTap: () => _openScreen(context, const ProgressScreen()),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _menuCard(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: _coral,
                      title: 'AI Review',
                      subtitle: 'Improve your UI',
                      onTap: () => _openScreen(context, const AiReviewScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _menuCard(
                      icon: Icons.shield_moon_rounded,
                      iconColor: _mint,
                      title: 'Guard',
                      subtitle: 'Block distractions',
                      onTap: () => _openScreen(
                        context,
                        const DistractionBlockerScreen(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  'SMALL STEPS. STRONGER YOU.',
                  style: TextStyle(
                    color: _muted.withValues(alpha: 0.7),
                    fontSize: 9,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _statChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(color: _cream, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static Widget _statusBar(String label, double progress, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFF403657),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(progress * 100).round()}%',
          style: const TextStyle(
            color: _cream,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static Widget _menuCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: _panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF403657)),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 25),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _cream,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }
}
