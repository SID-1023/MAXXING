import 'package:flutter/material.dart';

class FreshStartScreen extends StatelessWidget {
  const FreshStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090F),
        foregroundColor: Colors.white,
        title: const Text('A Fresh Start'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFB69CFF),
              size: 54,
            ),
            const SizedBox(height: 24),
            const Text(
              'Today is a fresh start.',
              style: TextStyle(
                color: Color(0xFFEAE7F2),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Plan your day, stay focused, and keep moving forward.',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'YOUR DAILY INTENTION',
              style: TextStyle(
                color: Color(0xFFB69CFF),
                fontSize: 12,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const _FreshStartCard(
              icon: Icons.flag_outlined,
              title: 'Set your intention',
              subtitle: 'Decide what matters most today.',
            ),
            const SizedBox(height: 14),
            const _FreshStartCard(
              icon: Icons.check_circle_outline_rounded,
              title: 'Choose one priority',
              subtitle: 'Start with one small, achievable task.',
            ),
            const SizedBox(height: 14),
            const _FreshStartCard(
              icon: Icons.favorite_outline_rounded,
              title: 'Take care of yourself',
              subtitle: 'Make time for rest, movement, and breaks.',
            ),
          ],
        ),
      ),
    );
  }
}

class _FreshStartCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FreshStartCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF262532)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 2),
          Icon(icon, color: const Color(0xFFB69CFF), size: 27),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFEAE7F2),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
