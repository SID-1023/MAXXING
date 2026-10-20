import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  static const String _storageKey = 'maxxing_tasks';

  static const Color _background = Color(0xFF09090F);
  static const Color _card = Color(0xFF12121A);
  static const Color _purple = Color(0xFFB69CFF);
  static const Color _green = Color(0xFF8ED9B0);
  static const Color _red = Color(0xFFFF8585);
  static const Color _orange = Color(0xFFFFC078);

  List<_ProgressTask> _tasks = [];
  bool _isLoading = true;
  String? _error;

  int get _total => _tasks.length;

  int get _completed => _tasks.where((task) => task.isCompleted).length;

  int get _pending => _total - _completed;

  double get _completionRate => _total == 0 ? 0.0 : _completed / _total;

  int get _highPriority => _tasks
      .where((task) => task.priority == 'High' && !task.isCompleted)
      .length;

  int get _mediumPriority => _tasks
      .where((task) => task.priority == 'Medium' && !task.isCompleted)
      .length;

  int get _lowPriority => _tasks
      .where((task) => task.priority == 'Low' && !task.isCompleted)
      .length;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int get _overdue {
    return _tasks.where((task) {
      return !task.isCompleted &&
          task.dueDate != null &&
          task.dueDate!.isBefore(_today);
    }).length;
  }

  int get _dueToday {
    return _tasks.where((task) {
      return !task.isCompleted &&
          task.dueDate != null &&
          task.dueDate == _today;
    }).length;
  }

  int get _dueNextSevenDays {
    final endDate = _today.add(const Duration(days: 7));

    return _tasks.where((task) {
      if (task.isCompleted || task.dueDate == null) {
        return false;
      }

      return !task.dueDate!.isBefore(_today) && !task.dueDate!.isAfter(endDate);
    }).length;
  }

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTasks = prefs.getString(_storageKey);

      List<_ProgressTask> loadedTasks = [];

      if (savedTasks != null) {
        final decoded = jsonDecode(savedTasks) as List<dynamic>;

        loadedTasks = decoded.map((item) {
          final json = Map<String, dynamic>.from(item as Map);

          return _ProgressTask(
            title: json['title'] as String? ?? '',
            priority: json['priority'] as String? ?? 'Medium',
            isCompleted: json['isCompleted'] as bool? ?? false,
            dueDate: DateTime.tryParse(json['dueDate'] as String? ?? ''),
          );
        }).toList();
      }

      if (!mounted) return;

      setState(() {
        _tasks = loadedTasks;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Error loading progress: $error');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = 'Could not load your progress. Please try again.';
      });
    }
  }

  String get _motivationalTitle {
    if (_total == 0) return 'Start with one small task.';
    if (_completionRate == 1) return 'Amazing work!';
    if (_completionRate >= 0.7) return 'You are doing great!';
    if (_overdue > 0) return 'Let’s tackle what’s overdue.';
    if (_completed > 0) return 'Keep your momentum going!';
    return 'Every small step counts.';
  }

  String get _motivationalMessage {
    if (_total == 0) {
      return 'Add a task to start tracking your productivity.';
    }
    if (_completionRate == 1) {
      return 'You completed every task on your list. Celebrate your progress!';
    }
    if (_overdue > 0) {
      return 'You have $_overdue overdue task${_overdue == 1 ? '' : 's'}. Choose one and make a start.';
    }
    if (_completed > 0) {
      return 'You have completed $_completed task${_completed == 1 ? '' : 's'}. Keep going at your own pace.';
    }
    return 'Choose your most important task and take the first step.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        title: const Text(
          'Your Progress',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh progress',
            onPressed: _loadProgress,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : _error != null
            ? _buildError()
            : RefreshIndicator(
                color: _purple,
                backgroundColor: _card,
                onRefresh: _loadProgress,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  children: [
                    _buildHeroCard(),
                    const SizedBox(height: 22),
                    _sectionTitle('Overview'),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.55,
                      children: [
                        _StatCard(
                          title: 'Total tasks',
                          value: '$_total',
                          icon: Icons.checklist_rounded,
                          color: _purple,
                        ),
                        _StatCard(
                          title: 'Completed',
                          value: '$_completed',
                          icon: Icons.task_alt_rounded,
                          color: _green,
                        ),
                        _StatCard(
                          title: 'Pending',
                          value: '$_pending',
                          icon: Icons.pending_actions_rounded,
                          color: _orange,
                        ),
                        _StatCard(
                          title: 'Overdue',
                          value: '$_overdue',
                          icon: Icons.warning_amber_rounded,
                          color: _red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Completion rate'),
                    const SizedBox(height: 12),
                    _buildCompletionCard(),
                    const SizedBox(height: 24),
                    _sectionTitle('Deadline tracker'),
                    const SizedBox(height: 12),
                    _buildDeadlineCard(),
                    const SizedBox(height: 24),
                    _sectionTitle('Pending by priority'),
                    const SizedBox(height: 12),
                    _buildPriorityCard(),
                    const SizedBox(height: 24),
                    _buildMotivationCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _red, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadProgress,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF28203D), Color(0xFF171522)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF44365F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.insights_rounded, color: _purple, size: 30),
          const SizedBox(height: 16),
          const Text(
            'Your productivity at a glance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_completed of $_total tasks completed',
            style: TextStyle(color: Colors.grey.shade300),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _completionRate,
              minHeight: 10,
              backgroundColor: const Color(0xFF403653),
              valueColor: const AlwaysStoppedAnimation<Color>(_purple),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${(_completionRate * 100).round()}% complete',
            style: const TextStyle(color: _purple, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Overall completion',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(_completionRate * 100).round()}%',
                style: const TextStyle(
                  color: _purple,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressBar(value: _completionRate, color: _purple),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Legend(color: _green, label: 'Completed ($_completed)'),
              ),
              Expanded(
                child: _Legend(color: _orange, label: 'Pending ($_pending)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _decoration(),
      child: Column(
        children: [
          _DeadlineRow(
            icon: Icons.today_rounded,
            label: 'Due today',
            count: _dueToday,
            color: _orange,
          ),
          const Divider(color: Color(0xFF292735), height: 24),
          _DeadlineRow(
            icon: Icons.date_range_rounded,
            label: 'Due in the next 7 days',
            count: _dueNextSevenDays,
            color: _purple,
          ),
          const Divider(color: Color(0xFF292735), height: 24),
          _DeadlineRow(
            icon: Icons.warning_amber_rounded,
            label: 'Overdue tasks',
            count: _overdue,
            color: _red,
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _decoration(),
      child: Column(
        children: [
          _PriorityRow(
            label: 'High priority',
            count: _highPriority,
            totalPending: _pending,
            color: _red,
          ),
          const SizedBox(height: 20),
          _PriorityRow(
            label: 'Medium priority',
            count: _mediumPriority,
            totalPending: _pending,
            color: _purple,
          ),
          const SizedBox(height: 20),
          _PriorityRow(
            label: 'Low priority',
            count: _lowPriority,
            totalPending: _pending,
            color: _green,
          ),
          const SizedBox(height: 14),
          Text(
            'Only unfinished tasks are included in this breakdown.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF171522),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF302544)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: _purple, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _motivationalTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _motivationalMessage,
                  style: TextStyle(color: Colors.grey.shade400, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  BoxDecoration _decoration() {
    return BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF262532)),
    );
  }
}

class _ProgressTask {
  final String title;
  final String priority;
  final bool isCompleted;
  final DateTime? dueDate;

  const _ProgressTask({
    required this.title,
    required this.priority,
    required this.isCompleted,
    required this.dueDate,
  });
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF262532)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;

  const _ProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 8,
        backgroundColor: const Color(0xFF302544),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _DeadlineRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ],
    );
  }
}

class _PriorityRow extends StatelessWidget {
  final String label;
  final int count;
  final int totalPending;
  final Color color;

  const _PriorityRow({
    required this.label,
    required this.count,
    required this.totalPending,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = totalPending == 0 ? 0.0 : count / totalPending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white70)),
            ),
            Text(
              '$count',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 7,
            backgroundColor: const Color(0xFF292735),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
