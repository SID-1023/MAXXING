import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'task_screens.dart';
import 'progress_screen.dart';
import 'focus_screen.dart';
import 'ai_review_screen.dart';
import 'distraction_blocker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _background = Color(0xFF17132B);
  static const Color _panel = Color(0xFF241D42);
  static const Color _cream = Color(0xFFF6EFE3);
  static const Color _coral = Color(0xFFFF8A65);
  static const Color _yellow = Color(0xFFFFD66B);
  static const Color _mint = Color(0xFF7ED9B0);
  static const Color _muted = Color(0xFFB9B1D0);

  static const String _happinessKey = 'biscuit_happiness';
  static const String _treatsKey = 'biscuit_treats';

  bool _biscuitIsBlinking = false;
  bool _isLoadingStats = true;

  int _biscuitHappiness = 90;
  int _biscuitTreats = 5;

  String _biscuitMessage = 'Ready to make today count?';

  Timer? _biscuitBlinkTimer;
  Timer? _biscuitBlinkOffTimer;

  @override
  void initState() {
    super.initState();
    _loadBiscuitStats();
    _startBiscuitBlinking();
  }

  // Load Biscuit's saved stats when the screen opens.
  Future<void> _loadBiscuitStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        _biscuitHappiness = (prefs.getInt(_happinessKey) ?? 90).clamp(0, 100);
        _biscuitTreats = (prefs.getInt(_treatsKey) ?? 5).clamp(0, 999);
        _isLoadingStats = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingStats = false;
      });

      debugPrint('Could not load Biscuit stats: $error');
    }
  }

  // Save Biscuit's stats on the device.
  Future<void> _saveBiscuitStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt(_happinessKey, _biscuitHappiness);
      await prefs.setInt(_treatsKey, _biscuitTreats);
    } catch (error) {
      debugPrint('Could not save Biscuit stats: $error');
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

  // Pet Biscuit to increase her happiness.
  void _petBiscuit() {
    if (_isLoadingStats) return;

    setState(() {
      _biscuitHappiness = (_biscuitHappiness + 3).clamp(0, 100);

      _biscuitMessage = _biscuitHappiness >= 100
          ? 'I am the happiest kitty! ❤️'
          : 'Purr... I love that! ❤️';
    });

    _saveBiscuitStats();
  }

  // Feed Biscuit using one available treat.
  void _feedBiscuit() {
    if (_isLoadingStats) return;

    if (_biscuitTreats <= 0) {
      setState(() {
        _biscuitMessage = 'No treats left! Earn more by focusing. 🐾';
      });
      return;
    }

    setState(() {
      _biscuitTreats--;

      _biscuitHappiness = (_biscuitHappiness + 10).clamp(0, 100);

      _biscuitMessage = _biscuitHappiness >= 100
          ? 'Yummy! I am so happy! 😻'
          : 'Yummy! Thank you! 😻';
    });

    _saveBiscuitStats();
  }

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  void dispose() {
    _biscuitBlinkTimer?.cancel();
    _biscuitBlinkOffTimer?.cancel();
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
                      Image.asset(
                        'assets/images/den_scene.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) {
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
                                  style: TextStyle(color: _muted, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        },
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
                      // Keep bottom: 5 so Biscuit stays on the carpet.
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
                      onPressed: _isLoadingStats ? null : _petBiscuit,
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
                      onPressed: _isLoadingStats ? null : _feedBiscuit,
                      icon: const Icon(Icons.restaurant_rounded),
                      label: Text(
                        _isLoadingStats
                            ? 'Loading...'
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
                          _biscuitHappiness >= 100
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

                    _statusBar('Energy', 0.8, _yellow),

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
