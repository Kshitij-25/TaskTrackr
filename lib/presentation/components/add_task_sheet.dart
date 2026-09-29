import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/task_model.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_tokens.dart';
import '../providers/auth_user_provider.dart';
import '../providers/momentum_provider.dart';
import '../providers/task_provider.dart';
import 'momentum_ui.dart';
import 'task_detail_sheet.dart' show pickDueDate;

/// [day] pre-selects a date (e.g. from the calendar) unless the text names one.
Future<void> showAddTaskSheet(BuildContext context,
        {String initial = '', DateTime? day}) =>
    showMomentumSheet(context, (_) => AddTaskSheet(initial: initial, day: day));

enum _Kind { title, project, priority, estimate, date, ghost }

class _Token {
  const _Token(this.label, this.kind);
  final String label;
  final _Kind kind;
}

/// Parsed natural-language capture:
/// "ship landing page tomorrow 2pm #work !high 45m".
class ParsedTask {
  ParsedTask(this.text) {
    var rest = text.trim();
    if (rest.isEmpty) return;

    final proj = RegExp(r'#(\w+)').firstMatch(rest);
    if (proj != null) {
      final key = proj.group(1)!;
      project = _projects.firstWhere(
        (p) => p.toLowerCase() == key.toLowerCase(),
        orElse: () => key[0].toUpperCase() + key.substring(1),
      );
      rest = rest.replaceFirst(proj.group(0)!, '');
    }

    final prio = RegExp(r'!(high|med|medium|low)\b', caseSensitive: false)
        .firstMatch(rest);
    if (prio != null) {
      final p = prio.group(1)!.toLowerCase();
      priority = p == 'high'
          ? 'High'
          : p == 'low'
              ? 'Low'
              : 'Medium';
      rest = rest.replaceFirst(prio.group(0)!, '');
    }

    final time = RegExp(
            r'\b(\d{1,2})(?::(\d{2}))?\s?(am|pm)\b|\b(\d{1,2}):(\d{2})\b',
            caseSensitive: false)
        .firstMatch(rest);
    if (time != null) {
      if (time.group(3) != null) {
        var h = int.parse(time.group(1)!) % 12;
        if (time.group(3)!.toLowerCase() == 'pm') h += 12;
        this.time = TimeOfDay(hour: h, minute: int.parse(time.group(2) ?? '0'));
      } else {
        this.time = TimeOfDay(
          hour: int.parse(time.group(4)!).clamp(0, 23),
          minute: int.parse(time.group(5)!).clamp(0, 59),
        );
      }
      timeLabel = time.group(0)!.toLowerCase();
      rest = rest.replaceFirst(time.group(0)!, '');
    }

    final est =
        RegExp(r'\b(\d+)\s?(m|min|mins|h|hr|hrs)\b', caseSensitive: false)
            .firstMatch(rest);
    if (est != null) {
      final n = int.parse(est.group(1)!);
      estimate = est.group(2)!.toLowerCase().startsWith('h') ? n * 60 : n;
      rest = rest.replaceFirst(est.group(0)!, '');
    }

    final day = RegExp(
      r'\b(today|tonight|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday|next week|weekend)\b',
      caseSensitive: false,
    ).firstMatch(rest);
    if (day != null) {
      dayWord = day.group(1)!.toLowerCase();
      rest = rest.replaceFirst(day.group(0)!, '');
    }

    title = rest.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const _projects = [
    'Work',
    'Personal',
    'Health',
    'Finance',
    'Learning',
    'Engineering',
    'Client',
  ];

  final String text;
  String title = '';
  String project = 'Inbox';
  String priority = 'Medium';
  int? estimate;
  String? dayWord;
  TimeOfDay? time;
  String? timeLabel;

  DateTime get due {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day);
    switch (dayWord) {
      case 'tomorrow':
        d = d.add(const Duration(days: 1));
      case 'next week':
        d = d.add(Duration(days: 8 - d.weekday));
      case 'weekend':
        d = d.add(Duration(days: (6 - d.weekday) % 7));
      case null || 'today' || 'tonight':
        break;
      default:
        const names = [
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
          'saturday',
          'sunday',
        ];
        final target = names.indexOf(dayWord!) + 1;
        var delta = (target - d.weekday) % 7;
        if (delta == 0) delta = 7;
        d = d.add(Duration(days: delta));
    }
    final t = time ??
        (dayWord == 'tonight'
            ? const TimeOfDay(hour: 20, minute: 0)
            : const TimeOfDay(hour: 18, minute: 0));
    var out = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (out.isBefore(now) && dayWord == null && time == null) {
      out = now.add(const Duration(hours: 1));
    }
    return out;
  }

  List<_Token> get tokens {
    if (text.trim().isEmpty) {
      return const [
        _Token('Type naturally — date, #project, !priority, 45m', _Kind.ghost)
      ];
    }
    return [
      _Token(title.isEmpty ? 'Untitled task' : title, _Kind.title),
      if (project != 'Inbox') _Token('#$project', _Kind.project),
      if (text.contains('!'))
        _Token('${priority.toLowerCase()} priority', _Kind.priority),
      if (estimate != null) _Token('${estimate}m', _Kind.estimate),
      if (dayWord != null) _Token(dayWord!, _Kind.date),
      if (timeLabel != null) _Token(timeLabel!, _Kind.date),
    ];
  }
}

class AddTaskSheet extends ConsumerStatefulWidget {
  const AddTaskSheet({super.key, this.initial = '', this.day});
  final String initial;
  final DateTime? day;

  @override
  ConsumerState<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _Template {
  const _Template(this.label, this.text, [this.subtasks = const []]);
  final String label;
  final String text;
  final List<String> subtasks;
}

const _templates = [
  _Template('Deep work', 'Deep work block today #work !high 90m',
      ['Silence notifications', 'Define the one outcome', 'Ship a draft']),
  _Template('Weekly review', 'Weekly review friday 4pm #work 30m', [
    'Clear the inbox',
    'Review last week’s wins',
    'Pick three bets for next week',
  ]),
  _Template('Workout', 'Workout tonight #health 45m'),
  _Template('Pay bills', 'Pay bills tomorrow #finance !high 15m',
      ['Check statements', 'Schedule payments']),
  _Template('Read', 'Read 20 pages tonight #learning !low 30m'),
  _Template('1:1 prep', '1:1 prep tomorrow 10am #work 20m',
      ['Wins since last time', 'Blockers', 'One ask']),
];

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  late final _ctrl = TextEditingController(text: widget.initial);
  bool _saving = false;
  _Template? _template;
  DateTime? _manualDue;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  DateTime _dueFor(ParsedTask p) {
    if (_manualDue != null) return _manualDue!;
    final day = widget.day;
    if (day != null && p.dayWord == null) {
      final t = p.time ?? const TimeOfDay(hour: 18, minute: 0);
      return DateTime(day.year, day.month, day.day, t.hour, t.minute);
    }
    return p.due;
  }

  Future<void> _pickDue() async {
    final due = await pickDueDate(context, _dueFor(ParsedTask(_ctrl.text)));
    if (due != null) setState(() => _manualDue = due);
  }

  Future<void> _save() async {
    final parsed = ParsedTask(_ctrl.text);
    if (parsed.title.isEmpty) {
      showMomentumToast(context, 'Nothing to add yet');
      return;
    }
    final userId = ref.read(currentUidProvider);
    if (userId == null) return;

    setState(() => _saving = true);
    final subs = _template != null && _ctrl.text == _template!.text
        ? _template!.subtasks
        : const <String>[];
    final task = TaskModel(
      id: '',
      title: parsed.title,
      dueDate: _dueFor(parsed),
      priority: parsed.priority,
      category: parsed.project,
      userId: userId,
      estimateMinutes: parsed.estimate ?? 30,
      subtasks: [for (final s in subs) Subtask(title: s)],
    );
    // Firestore queues the write offline; don't block the UI on the network.
    await ref.read(taskActionsProvider).addTask(task).catchError((Object e) {
      if (mounted) showMomentumToast(context, 'Could not save: $e');
    });
    final granted = ref.read(momentumProvider.notifier).award(XpSource.capture);
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    Navigator.pop(context);
    showMomentumToast(
        context,
        granted > 0
            ? 'Captured · +$granted XP for planning ahead'
            : 'Captured');
  }

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    final parsed = ParsedTask(_ctrl.text);

    Color tokenColor(_Kind k) => switch (k) {
          _Kind.title => m.ink,
          _Kind.project => m.violet,
          _Kind.priority => m.danger,
          _Kind.estimate => m.cyan,
          _Kind.date => m.amber,
          _Kind.ghost => m.inkTertiary,
        };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add anything',
              style: AppTypography.heading2.copyWith(color: m.ink)),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            textInputAction: TextInputAction.done,
            cursorColor: m.violet,
            style:
                AppTypography.bodyStrong.copyWith(color: m.ink, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Ship landing page tomorrow 2pm #work !high 45m',
              hintStyle: AppTypography.body.copyWith(color: m.inkTertiary),
              filled: true,
              fillColor: m.ink.withValues(alpha: .05),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MomentumTokens.radiusRow),
                borderSide: BorderSide(color: m.stroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MomentumTokens.radiusRow),
                borderSide: BorderSide(
                    color: m.violet.withValues(alpha: .7), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in parsed.tokens)
                AnimatedContainer(
                  duration:
                      AppMotion.of(context, const Duration(milliseconds: 200)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: m.ink
                        .withValues(alpha: t.kind == _Kind.title ? .1 : .05),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: t.kind == _Kind.title || t.kind == _Kind.ghost
                          ? m.ink.withValues(alpha: .12)
                          : tokenColor(t.kind).withValues(alpha: .35),
                    ),
                  ),
                  child: Text(
                    t.label,
                    style: AppTypography.caption.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: tokenColor(t.kind),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickDue,
            child: Row(children: [
              Icon(Icons.event_outlined, size: 14, color: m.amber),
              const SizedBox(width: 6),
              Text(
                'Due ${DateFormat('EEE d MMM · HH:mm').format(_dueFor(parsed))}',
                style: AppTypography.label
                    .copyWith(color: m.inkSecondary, letterSpacing: .6),
              ),
              const SizedBox(width: 6),
              Text(_manualDue == null ? 'CHANGE' : 'SET',
                  style: AppTypography.label
                      .copyWith(color: m.cyan, fontSize: 9.5)),
            ]),
          ),
          if (_ctrl.text.trim().isEmpty) ...[
            const SizedBox(height: 18),
            const SectionLabel('Templates'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _templates)
                  FilterPill(
                    label: t.label,
                    selected: false,
                    onTap: () => setState(() {
                      _template = t;
                      _ctrl.text = t.text;
                      _ctrl.selection =
                          TextSelection.collapsed(offset: t.text.length);
                    }),
                  ),
              ],
            ),
          ],
          if (_template != null &&
              _ctrl.text == _template!.text &&
              _template!.subtasks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '+ ${_template!.subtasks.length} subtasks: '
              '${_template!.subtasks.join(' · ')}',
              style: AppTypography.caption
                  .copyWith(color: m.inkTertiary, fontSize: 11.5),
            ),
          ],
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: MButton(
                label: ref.watch(gamificationProvider) == GamificationMode.off
                    ? 'Add task'
                    : 'Add task · +${XpSource.capture.xp} XP',
                loading: _saving,
                onPressed: _save,
              ),
            ),
            const SizedBox(width: 8),
            MButton(
              label: 'Cancel',
              kind: MButtonKind.ghost,
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'NATURAL LANGUAGE  ·  #PROJECT  ·  !PRIORITY  ·  45M',
              style: AppTypography.label
                  .copyWith(fontSize: 9.5, color: m.inkTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
