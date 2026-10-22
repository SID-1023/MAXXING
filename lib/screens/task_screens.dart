import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _bg = Color(0xFF17132B);
const Color _panel = Color(0xFF241D42);
const Color _cream = Color(0xFFF6EFE3);
const Color _muted = Color(0xFFB8B0CC);
const Color _coral = Color(0xFFFF8A65);
const Color _yellow = Color(0xFFFFD66B);
const Color _mint = Color(0xFF7ED9B0);
const Color _border = Color(0xFF45385F);

enum _TaskFilter { all, pending, upcoming, overdue, completed }

Color _priorityColor(String priority) {
  switch (priority) {
    case 'High':
      return _coral;
    case 'Low':
      return _mint;
    default:
      return _yellow;
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

class _Task {
  String id;
  String title;
  String priority;
  bool completed;
  DateTime? dueDate;
  DateTime createdAt;

  _Task({
    required this.id,
    required this.title,
    this.priority = 'Medium',
    this.completed = false,
    this.dueDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory _Task.fromJson(Map<String, dynamic> json) {
    return _Task(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: (json['title'] ?? 'Untitled task').toString(),
      priority: ['Low', 'Medium', 'High'].contains(json['priority'])
          ? json['priority'].toString()
          : 'Medium',
      completed: json['completed'] == true,
      dueDate: DateTime.tryParse(
        (json['dueDate'] ?? json['due_date'] ?? '').toString(),
      ),
      createdAt:
          DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'priority': priority,
    'completed': completed,
    'dueDate': dueDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}

/// The create/edit dialog. It owns its TextEditingController and disposes it
/// in its own State, which Flutter only does after the dialog is fully gone.
class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({this.existing});

  final _Task? existing;

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  late final TextEditingController _titleController;
  late String _priority;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _priority = widget.existing?.priority ?? 'Medium';
    _dueDate = widget.existing?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _yellow,
              onPrimary: _bg,
              surface: _panel,
              onSurface: _cream,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final existing = widget.existing;
    final task = _Task(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      priority: _priority,
      completed: existing?.completed ?? false,
      dueDate: _dueDate,
      createdAt: existing?.createdAt,
    );

    Navigator.pop(context, task);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

    return AlertDialog(
      backgroundColor: _panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: _border),
      ),
      title: Text(
        isNew ? 'New quest ✨' : 'Edit quest ✨',
        style: const TextStyle(color: _cream, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What would you like to accomplish?',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              autofocus: true,
              maxLength: 100,
              style: const TextStyle(color: _cream),
              decoration: InputDecoration(
                hintText: 'e.g. Finish my project',
                hintStyle: const TextStyle(color: _muted),
                filled: true,
                fillColor: _bg,
                counterStyle: const TextStyle(color: _muted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'PRIORITY',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: ['Low', 'Medium', 'High'].map((value) {
                final selected = _priority == value;
                final color = _priorityColor(value);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _priority = value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? color.withValues(alpha: 0.15) : _bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? color : _border),
                        ),
                        child: Text(
                          value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? color : _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'DUE DATE',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: _yellow),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _dueDate == null
                            ? 'Choose a date (optional)'
                            : _formatDate(_dueDate!),
                        style: TextStyle(
                          color: _dueDate == null ? _muted : _cream,
                        ),
                      ),
                    ),
                    if (_dueDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _dueDate = null),
                        child: const Icon(
                          Icons.close_rounded,
                          color: _muted,
                          size: 19,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _muted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _yellow,
            foregroundColor: _bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _submit,
          child: Text(isNew ? 'Create quest' : 'Save changes'),
        ),
      ],
    );
  }
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const String _storageKey = 'maxxing_tasks';

  final List<_Task> _tasks = [];
  _TaskFilter _filter = _TaskFilter.all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);

      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);

        if (decoded is List) {
          _tasks
            ..clear()
            ..addAll(
              decoded.whereType<Map>().map(
                (item) => _Task.fromJson(Map<String, dynamic>.from(item)),
              ),
            );
        }
      }
    } catch (error) {
      debugPrint('Could not load MAXXING tasks: $error');
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(_tasks.map((task) => task.toJson()).toList()),
      );
    } catch (error) {
      debugPrint('Could not save MAXXING tasks: $error');

      if (!mounted || !context.mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not save tasks.')),
        );
      }
    }
  }

  int get _completedCount => _tasks.where((task) => task.completed).length;

  int get _pendingCount => _tasks.where((task) => !task.completed).length;

  int get _overdueCount =>
      _tasks.where((task) => !task.completed && _isOverdue(task)).length;

  int get _upcomingCount =>
      _tasks.where((task) => !task.completed && _isUpcoming(task)).length;

  double get _progress => _tasks.isEmpty ? 0 : _completedCount / _tasks.length;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isOverdue(_Task task) {
    final due = task.dueDate;
    if (due == null || task.completed) return false;

    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(due).isBefore(today);
  }

  bool _isUpcoming(_Task task) {
    final due = task.dueDate;
    if (due == null || task.completed) return false;

    final today = DateUtils.dateOnly(DateTime.now());
    return !DateUtils.dateOnly(due).isBefore(today);
  }

  List<_Task> get _filteredTasks {
    final result = _tasks.where((task) {
      switch (_filter) {
        case _TaskFilter.all:
          return true;
        case _TaskFilter.pending:
          return !task.completed;
        case _TaskFilter.upcoming:
          return _isUpcoming(task);
        case _TaskFilter.overdue:
          return _isOverdue(task);
        case _TaskFilter.completed:
          return task.completed;
      }
    }).toList();

    result.sort((a, b) {
      if (a.completed != b.completed) {
        return a.completed ? 1 : -1;
      }

      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;

      const priorityRank = {'High': 0, 'Medium': 1, 'Low': 2};
      return (priorityRank[a.priority] ?? 1).compareTo(
        priorityRank[b.priority] ?? 1,
      );
    });

    return result;
  }

  Future<void> _showTaskEditor({_Task? existing}) async {
    final result = await showDialog<_Task>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TaskEditorDialog(existing: existing),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (existing == null) {
        _tasks.add(result);
      } else {
        final index = _tasks.indexWhere((task) => task.id == existing.id);
        if (index != -1) _tasks[index] = result;
      }
    });

    await _saveTasks();
  }

  Future<void> _toggleTask(_Task task) async {
    setState(() => task.completed = !task.completed);
    await _saveTasks();
  }

  Future<void> _deleteTask(_Task task) async {
    final removedIndex = _tasks.indexOf(task);
    if (removedIndex == -1) return;

    setState(() => _tasks.remove(task));
    await _saveTasks();

    if (!mounted || !context.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('"${task.title}" deleted'),
        backgroundColor: _panel,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: _yellow,
          onPressed: () async {
            if (!mounted) return;
            setState(() {
              _tasks.insert(removedIndex.clamp(0, _tasks.length), task);
            });
            await _saveTasks();
          },
        ),
      ),
    );
  }

  String _deadlineText(_Task task) {
    final due = task.dueDate;
    if (due == null) return 'No due date';
    if (task.completed) return 'Due ${_formatDate(due)}';
    if (_isOverdue(task)) return 'Overdue · ${_formatDate(due)}';

    final today = DateUtils.dateOnly(DateTime.now());
    final dueDay = DateUtils.dateOnly(due);

    if (_sameDay(today, dueDay)) return 'Due today';
    if (_sameDay(today.add(const Duration(days: 1)), dueDay)) {
      return 'Due tomorrow';
    }
    return 'Due ${_formatDate(due)}';
  }

  Color _deadlineColor(_Task task) {
    if (task.completed) return _mint;
    if (_isOverdue(task)) return _coral;
    if (task.dueDate != null) return _yellow;
    return _muted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskEditor(),
        backgroundColor: _yellow,
        foregroundColor: _bg,
        elevation: 5,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New quest',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _yellow))
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeader(),
                        const SizedBox(height: 26),
                        _buildProgressCard(),
                        const SizedBox(height: 28),
                        _buildSectionHeader(),
                        const SizedBox(height: 14),
                        _buildFilters(),
                        const SizedBox(height: 16),
                        if (_filteredTasks.isEmpty)
                          _buildEmptyState()
                        else
                          ..._filteredTasks.map(_buildTaskCard),
                        const SizedBox(height: 84),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Material(
          color: _panel,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.maybePop(context),
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.arrow_back_rounded, color: _cream, size: 23),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR QUESTS',
                style: TextStyle(
                  color: _cream,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Small steps. Big growth.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: _mint, size: 17),
              const SizedBox(width: 6),
              Text(
                '$_completedCount/${_tasks.length}',
                style: const TextStyle(
                  color: _cream,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: _yellow.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _yellow,
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your daily growth',
                      style: TextStyle(
                        color: _cream,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Every completed quest counts.',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '${(_progress * 100).round()}%',
                style: const TextStyle(
                  color: _mint,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 21),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 9,
              backgroundColor: const Color(0xFF403454),
              valueColor: const AlwaysStoppedAnimation<Color>(_mint),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  Icons.radio_button_unchecked_rounded,
                  'Pending',
                  '$_pendingCount',
                  _yellow,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                  Icons.schedule_rounded,
                  'Upcoming',
                  '$_upcomingCount',
                  _mint,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                  Icons.warning_amber_rounded,
                  'Overdue',
                  '$_overdueCount',
                  _coral,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 9),
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: _cream,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'TODAY\'S QUESTS',
            style: TextStyle(
              color: _cream,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        Text(
          '${_filteredTasks.length} tasks',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    const filters = [
      _TaskFilter.all,
      _TaskFilter.pending,
      _TaskFilter.upcoming,
      _TaskFilter.overdue,
      _TaskFilter.completed,
    ];

    const labels = {
      _TaskFilter.all: 'All',
      _TaskFilter.pending: 'Pending',
      _TaskFilter.upcoming: 'Upcoming',
      _TaskFilter.overdue: 'Overdue',
      _TaskFilter.completed: 'Done',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _filter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => setState(() => _filter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: selected ? _yellow : _panel,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: selected ? _yellow : _border),
                ),
                child: Text(
                  labels[filter]!,
                  style: TextStyle(
                    color: selected ? _bg : _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskCard(_Task task) {
    final priorityColor = _priorityColor(task.priority);
    final deadlineColor = _deadlineColor(task);

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 22),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: _coral.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: _coral,
          size: 26,
        ),
      ),
      onDismissed: (_) => _deleteTask(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showTaskEditor(existing: task),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggleTask(task),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, right: 13),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: task.completed ? _mint : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: task.completed ? _mint : _muted,
                          width: 1.8,
                        ),
                      ),
                      child: task.completed
                          ? const Icon(
                              Icons.check_rounded,
                              color: _bg,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          color: task.completed ? _muted : _cream,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: task.completed
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: _muted,
                        ),
                      ),
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _tag(task.priority.toUpperCase(), priorityColor),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                task.dueDate == null
                                    ? Icons.event_available_rounded
                                    : Icons.calendar_today_rounded,
                                size: 12,
                                color: deadlineColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _deadlineText(task),
                                style: TextStyle(
                                  color: deadlineColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Task options',
                  icon: const Icon(Icons.more_horiz_rounded, color: _muted),
                  color: _panel,
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showTaskEditor(existing: task);
                    } else if (value == 'delete') {
                      _deleteTask(task);
                    } else if (value == 'toggle') {
                      _toggleTask(task);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: _yellow, size: 19),
                          SizedBox(width: 10),
                          Text('Edit task', style: TextStyle(color: _cream)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            task.completed
                                ? Icons.refresh_rounded
                                : Icons.check_circle_outline_rounded,
                            color: _mint,
                            size: 19,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            task.completed ? 'Mark pending' : 'Mark complete',
                            style: const TextStyle(color: _cream),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: _coral,
                            size: 19,
                          ),
                          SizedBox(width: 10),
                          Text('Delete task', style: TextStyle(color: _cream)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isAll = _filter == _TaskFilter.all;
    final isCompleted = _filter == _TaskFilter.completed;

    final icon = isAll
        ? Icons.pets_rounded
        : isCompleted
        ? Icons.emoji_events_rounded
        : Icons.spa_rounded;

    final title = isAll
        ? 'Your quest starts here'
        : isCompleted
        ? 'No completed quests yet'
        : 'Nothing on this list';

    final subtitle = isAll
        ? 'Add a small goal and help Biscuit grow.'
        : isCompleted
        ? 'Complete a task to celebrate your progress.'
        : 'Looking good! You can enjoy this breathing room.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _yellow.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _yellow, size: 37),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _cream,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
          ),
          if (isAll) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _showTaskEditor(),
              style: OutlinedButton.styleFrom(
                foregroundColor: _yellow,
                side: const BorderSide(color: _yellow),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create your first quest'),
            ),
          ],
        ],
      ),
    );
  }
}
