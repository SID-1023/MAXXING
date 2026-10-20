import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final List<_Task> _tasks = [];

  String _filter = 'All';
  bool _isLoading = true;

  static const String _storageKey = 'maxxing_tasks';

  static const Color _background = Color(0xFF09090F);
  static const Color _card = Color(0xFF12121A);
  static const Color _purple = Color(0xFFB69CFF);
  static const Color _red = Color(0xFFFF8585);
  static const Color _green = Color(0xFF8ED9B0);
  static const Color _orange = Color(0xFFFFC078);

  int get _completedCount => _tasks.where((task) => task.isCompleted).length;

  int get _pendingCount => _tasks.length - _completedCount;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isOverdue(_Task task) {
    return !task.isCompleted &&
        task.dueDate != null &&
        task.dueDate!.isBefore(_today);
  }

  int get _overdueCount => _tasks.where(_isOverdue).length;

  int get _upcomingCount {
    final endDate = _today.add(const Duration(days: 7));

    return _tasks.where((task) {
      if (task.isCompleted || task.dueDate == null) {
        return false;
      }

      return !task.dueDate!.isBefore(_today) && !task.dueDate!.isAfter(endDate);
    }).length;
  }

  List<_Task> get _filteredTasks {
    if (_filter == 'Pending') {
      return _tasks.where((task) => !task.isCompleted).toList();
    }

    if (_filter == 'Completed') {
      return _tasks.where((task) => task.isCompleted).toList();
    }

    if (_filter == 'Overdue') {
      return _tasks.where(_isOverdue).toList();
    }

    if (_filter == 'Upcoming') {
      final endDate = _today.add(const Duration(days: 7));

      return _tasks.where((task) {
        if (task.isCompleted || task.dueDate == null) {
          return false;
        }

        return !task.dueDate!.isBefore(_today) &&
            !task.dueDate!.isAfter(endDate);
      }).toList();
    }

    return _tasks;
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTasks = prefs.getString(_storageKey);

      if (savedTasks != null) {
        final decoded = jsonDecode(savedTasks) as List<dynamic>;

        final loadedTasks = decoded
            .map(
              (item) => _Task.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();

        if (!mounted) return;

        setState(() {
          _tasks
            ..clear()
            ..addAll(loadedTasks);
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (error) {
      debugPrint('Error loading MAXXING tasks: $error');

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load saved tasks.')),
      );
    }
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final encodedTasks = jsonEncode(
        _tasks.map((task) => task.toJson()).toList(),
      );

      await prefs.setString(_storageKey, encodedTasks);
    } catch (error) {
      debugPrint('Error saving MAXXING tasks: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save tasks. Please try again.'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _addTask() async {
    final result = await showDialog<_Task>(
      context: context,
      builder: (_) => const _AddTaskDialog(),
    );

    if (!mounted || result == null) return;

    setState(() {
      _tasks.insert(0, result);
    });

    await _saveTasks();
  }

  Future<void> _toggleTask(_Task task, bool? checked) async {
    setState(() {
      task.isCompleted = checked ?? false;
    });

    await _saveTasks();
  }

  Future<void> _deleteTask(_Task task) async {
    setState(() {
      _tasks.remove(task);
    });

    await _saveTasks();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task deleted'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return _red;
      case 'Low':
        return _green;
      default:
        return _purple;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _deadlineText(_Task task) {
    final dueDate = task.dueDate!;

    if (task.isCompleted) {
      return 'Due ${_formatDate(dueDate)}';
    }

    if (_isOverdue(task)) {
      final daysLate = _today.difference(dueDate).inDays;

      if (daysLate == 1) return 'Overdue by 1 day';
      return 'Overdue by $daysLate days';
    }

    if (dueDate == _today) return 'Due today';

    if (dueDate == _today.add(const Duration(days: 1))) {
      return 'Due tomorrow';
    }

    return 'Due ${_formatDate(dueDate)}';
  }

  Color _deadlineColor(_Task task) {
    if (task.isCompleted) return _green;
    if (_isOverdue(task)) return _red;
    if (task.dueDate == _today) return _orange;
    return Colors.grey.shade400;
  }

  Widget _buildOverviewCard() {
    final total = _tasks.length;
    final progress = total == 0 ? 0.0 : _completedCount / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF171522),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF302544)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Make today count.',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_completedCount of $total tasks completed',
            style: TextStyle(color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF302544),
              valueColor: const AlwaysStoppedAnimation<Color>(_purple),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.pending_actions_rounded,
                  label: 'Pending',
                  value: '$_pendingCount',
                  color: _purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  icon: Icons.event_available_rounded,
                  label: 'Due soon',
                  value: '$_upcomingCount',
                  color: _orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  icon: Icons.warning_amber_rounded,
                  label: 'Overdue',
                  value: '$_overdueCount',
                  color: _red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _filteredTasks;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        title: const Text(
          'My Tasks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _addTask,
        backgroundColor: _purple,
        foregroundColor: _background,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Task',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: _buildOverviewCard(),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children:
                          [
                            'All',
                            'Pending',
                            'Upcoming',
                            'Overdue',
                            'Completed',
                          ].map((filter) {
                            final selected = _filter == filter;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(filter),
                                selected: selected,
                                onSelected: (_) {
                                  setState(() => _filter = filter);
                                },
                                selectedColor: _purple,
                                backgroundColor: _card,
                                labelStyle: TextStyle(
                                  color: selected
                                      ? _background
                                      : Colors.white70,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                side: BorderSide.none,
                                showCheckmark: false,
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: tasks.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _filter == 'Overdue'
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.task_alt_rounded,
                                    color: _purple,
                                    size: 54,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _emptyTitle(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _emptyMessage(),
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            itemCount: tasks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              final overdue = _isOverdue(task);

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: overdue
                                        ? _red.withValues(alpha: 0.65)
                                        : const Color(0xFF262532),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: task.isCompleted,
                                      onChanged: (value) =>
                                          _toggleTask(task, value),
                                      activeColor: _purple,
                                      checkColor: _background,
                                      side: const BorderSide(
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.title,
                                            style: TextStyle(
                                              color: task.isCompleted
                                                  ? Colors.grey
                                                  : Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              decoration: task.isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : TextDecoration.none,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 6,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              _LabelDot(
                                                color: _priorityColor(
                                                  task.priority,
                                                ),
                                                text:
                                                    '${task.priority} priority',
                                              ),
                                              if (task.dueDate != null)
                                                _LabelDot(
                                                  color: _deadlineColor(task),
                                                  icon: overdue
                                                      ? Icons.warning_rounded
                                                      : Icons.calendar_today,
                                                  text: _deadlineText(task),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete task',
                                      onPressed: () => _deleteTask(task),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  String _emptyTitle() {
    switch (_filter) {
      case 'Pending':
        return 'No pending tasks';
      case 'Completed':
        return 'No completed tasks yet';
      case 'Upcoming':
        return 'No upcoming deadlines';
      case 'Overdue':
        return 'You are all caught up!';
      default:
        return 'Your task list is clear';
    }
  }

  String _emptyMessage() {
    switch (_filter) {
      case 'Pending':
        return 'All your tasks are completed. Great work!';
      case 'Completed':
        return 'Finish a task and it will appear here.';
      case 'Upcoming':
        return 'Tasks due today or within the next 7 days appear here.';
      case 'Overdue':
        return 'You have no overdue, unfinished tasks.';
      default:
        return 'Tap Add Task to plan your next move.';
    }
  }
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog();

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final TextEditingController _controller = TextEditingController();

  String _priority = 'Medium';
  DateTime? _dueDate;

  static const Color _background = Color(0xFF09090F);
  static const Color _card = Color(0xFF12121A);
  static const Color _purple = Color(0xFFB69CFF);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _chooseDueDate() async {
    final now = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select task deadline',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _purple,
              onPrimary: _background,
              surface: _card,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null && mounted) {
      setState(() {
        _dueDate = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
      });
    }
  }

  void _submitTask() {
    final title = _controller.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    Navigator.of(
      context,
    ).pop(_Task(title: title, priority: _priority, dueDate: _dueDate));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _card,
      title: const Text('Create a task', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _submitTask(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'What do you need to do?',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                filled: true,
                fillColor: _background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Priority', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              dropdownColor: _card,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: _background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: ['Low', 'Medium', 'High']
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _priority = value);
                }
              },
            ),
            const SizedBox(height: 18),
            const Text(
              'Due date (optional)',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _chooseDueDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: _background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: _purple),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _dueDate == null
                            ? 'Choose a deadline'
                            : _formatDate(_dueDate!),
                        style: TextStyle(
                          color: _dueDate == null
                              ? Colors.grey.shade400
                              : Colors.white,
                        ),
                      ),
                    ),
                    if (_dueDate != null)
                      IconButton(
                        tooltip: 'Remove deadline',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() => _dueDate = null);
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: _background,
          ),
          onPressed: _submitTask,
          child: const Text('Add task'),
        ),
      ],
    );
  }
}

class _Task {
  final String title;
  final String priority;
  bool isCompleted;
  final DateTime? dueDate;

  _Task({
    required this.title,
    required this.priority,
    this.isCompleted = false,
    this.dueDate,
  });

  factory _Task.fromJson(Map<String, dynamic> json) {
    // dueDate is optional so tasks saved before this update still load.
    final savedDate = json['dueDate'] as String?;

    return _Task(
      title: json['title'] as String? ?? '',
      priority: json['priority'] as String? ?? 'Medium',
      isCompleted: json['isCompleted'] as bool? ?? false,
      dueDate: savedDate == null ? null : DateTime.tryParse(savedDate),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'priority': priority,
      'isCompleted': isCompleted,
      'dueDate': dueDate?.toIso8601String(),
    };
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF09090F).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _LabelDot extends StatelessWidget {
  final Color color;
  final String text;
  final IconData? icon;

  const _LabelDot({required this.color, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
        ] else ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
