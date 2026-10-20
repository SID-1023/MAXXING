import 'package:flutter/material.dart';

import '../widgets/feature_card.dart';
import 'task_screens.dart';
import 'progress_screen.dart';
import 'focus_screen.dart';
import 'ai_review_screen.dart';
import 'fresh_start_screen.dart';
import 'distraction_blocker_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color _background = Color(0xFF09090F);
  static const Color _textColor = Color(0xFFEAE7F2);
  static const Color _accent = Color(0xFFB69CFF);

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),

              // MAXXING branding
              const Text(
                'MAXXING',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'BUILD YOUR BEST SELF.',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Your day. Your progress.',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Small steps. Bigger results.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),

              const SizedBox(height: 26),

              // Welcome card
              Material(
                color: const Color(0xFF171522),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    _openScreen(context, const FreshStartScreen());
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF302544)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: _accent,
                          size: 28,
                        ),

                        const SizedBox(height: 18),

                        const Text(
                          'Today is a fresh start.',
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Plan your day, stay focused, '
                          'and keep moving forward.',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Workspace heading
              const Text(
                'YOUR WORKSPACE',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 12,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Tasks and Progress
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: FeatureCard(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Tasks',
                      subtitle: 'Plan your day',
                      onTap: () {
                        _openScreen(context, const TasksScreen());
                      },
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: FeatureCard(
                      icon: Icons.track_changes_rounded,
                      title: 'Progress',
                      subtitle: 'Track your growth',
                      onTap: () {
                        _openScreen(context, const ProgressScreen());
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Focus and AI Review
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: FeatureCard(
                      icon: Icons.timer_outlined,
                      title: 'Focus',
                      subtitle: 'Use time wisely',
                      onTap: () {
                        _openScreen(context, const FocusScreen());
                      },
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: FeatureCard(
                      icon: Icons.auto_awesome_outlined,
                      title: 'AI Review',
                      subtitle: 'Improve your UI',
                      onTap: () {
                        _openScreen(context, const AiReviewScreen());
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Distraction Blocker
              FeatureCard(
                icon: Icons.shield_moon_outlined,
                title: 'Distraction Blocker',
                subtitle: 'Control distracting websites and apps',
                onTap: () {
                  _openScreen(context, const DistractionBlockerScreen());
                },
              ),

              const SizedBox(height: 28),

              // Footer
              Center(
                child: Text(
                  'CONSISTENCY OVER PERFECTION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}
