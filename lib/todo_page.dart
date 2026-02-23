import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  DateTime _visibleMonth = DateTime.now();
  Set<String> _datesWithTasks = {}; // keys yyyy-MM-dd
  List<Map<String, dynamic>> _recurring = [];
  List<Map<String, dynamic>> _todayTasks = [];

  @override
  void initState() {
    super.initState();
    _loadMonthlyTasks();
  }

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  int _daysInMonth(DateTime d) {
    final first = DateTime(d.year, d.month, 1);
    final next = DateTime(d.year, d.month + 1, 1);
    return next.difference(first).inDays;
  }

  Future<void> _loadMonthlyTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final days = _daysInMonth(_visibleMonth);
    final Set<String> found = {};
    // load recurring tasks
    _recurring = [];
    try {
      final rjson = prefs.getString('todos_recurring');
      if (rjson != null) {
        final List<dynamic> rl = json.decode(rjson);
        _recurring = rl.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    for (int i = 1; i <= days; i++) {
      final d = DateTime(year, month, i);
      final key = 'todos_${_dateKey(d)}';
      final s = prefs.getString(key);
      if (s != null) {
        try {
          final List<dynamic> list = json.decode(s);
          if (list.isNotEmpty) found.add(_dateKey(d));
        } catch (_) {}
      }
      // check recurring tasks that apply to this date
      for (final r in _recurring) {
        try {
          final start = DateTime.parse(r['start'] as String);
          final rule = (r['rule'] ?? 'none').toString();
          if (_recurrenceApplies(rule, start, d)) {
            found.add(_dateKey(d));
            break;
          }
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      _datesWithTasks = found;
    });
    await _loadTodayTasks();
  }

  Future<void> _loadTodayTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final key = 'todos_${_dateKey(today)}';
    final List<Map<String, dynamic>> out = [];
    try {
      final s = prefs.getString(key);
      if (s != null) {
        final List<dynamic> list = json.decode(s);
        for (final it in list) {
          if (it is String) {
            out.add({'text': it, 'done': false, 'recurring': false});
          } else if (it is Map) {
            final m = Map<String, dynamic>.from(it);
            out.add({'text': m['text']?.toString() ?? '', 'done': m['done'] == true, 'time': m['time']?.toString(), 'recurring': false});
          }
        }
      }
    } catch (_) {}
    // include recurring tasks for today
    try {
      final rjson = prefs.getString('todos_recurring');
      if (rjson != null) {
        final List<dynamic> rl = json.decode(rjson);
        final recur = rl.map((e) => Map<String, dynamic>.from(e)).toList();
        for (final r in recur) {
          try {
            final start = DateTime.parse(r['start'] as String);
            final rule = (r['rule'] ?? 'none').toString();
            if (_recurrenceApplies(rule, start, today)) {
              final rid = r['id']?.toString() ?? '';
              final doneKey = 'todos_done_${_dateKey(today)}';
              List<dynamic> doneList = [];
              try {
                final ds = prefs.getString(doneKey);
                if (ds != null) doneList = json.decode(ds);
              } catch (_) {}
              out.add({'text': r['text']?.toString() ?? '', 'done': doneList.contains(rid), 'recurring': true, 'rid': rid, 'rule': rule, 'time': r['time']?.toString()});
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _todayTasks = out;
    });
  }

  Future<void> _toggleRecurringDone(String rid, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'todos_done_${_dateKey(DateTime.now())}';
    List<dynamic> doneList = [];
    try {
      final ds = prefs.getString(key);
      if (ds != null) doneList = json.decode(ds);
    } catch (_) {}
    if (value) {
      if (!doneList.contains(rid)) doneList.add(rid);
    } else {
      doneList.removeWhere((e) => e.toString() == rid);
    }
    await prefs.setString(key, json.encode(doneList));
    await _loadTodayTasks();
  }

  Future<void> _confirmRemoveRecurring(String rid) async {
    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove recurring task?'),
        content: Text('This will remove the recurring task for all dates.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final rjson = prefs.getString('todos_recurring');
      if (rjson != null) {
        final List<dynamic> rl = json.decode(rjson);
        final recur = rl.map((e) => Map<String, dynamic>.from(e)).where((r) => (r['id']?.toString() ?? '') != rid).toList();
        await prefs.setString('todos_recurring', json.encode(recur));
      }
    } catch (_) {}
    await _loadTodayTasks();
    await _loadMonthlyTasks();
  }

  Future<void> _deleteOneOffTodayTask(int idx) async {
    final today = DateTime.now();
    final key = 'todos_${_dateKey(today)}';
    final prefs = await SharedPreferences.getInstance();
    try {
      final s = prefs.getString(key);
      if (s == null) return;
      final List<dynamic> list = json.decode(s);
      final target = _todayTasks[idx];
      // find matching entry by text and time (if available)
      int foundIndex = -1;
      for (int i = 0; i < list.length; i++) {
        final it = list[i];
        if (it is String) {
          if (it == (target['text']?.toString() ?? '')) { foundIndex = i; break; }
        } else if (it is Map) {
          final m = Map<String, dynamic>.from(it);
          final ttext = m['text']?.toString() ?? '';
          final ttime = m['time']?.toString();
          if (ttext == (target['text']?.toString() ?? '') && (ttime == target['time']?.toString())) { foundIndex = i; break; }
        }
      }
      if (foundIndex >= 0) {
        list.removeAt(foundIndex);
        await prefs.setString(key, json.encode(list));
      }
    } catch (_) {}
    await _loadTodayTasks();
    await _loadMonthlyTasks();
  }

  bool _recurrenceApplies(String rule, DateTime start, DateTime date) {
    if (date.isBefore(start)) return false;
    switch (rule) {
      case 'daily':
        return true;
      case 'weekly':
        return date.weekday == start.weekday;
      case 'monthly':
        return date.day == start.day;
      default:
        return false;
    }
  }

  void _prevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    });
    _loadMonthlyTasks();
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    });
    _loadMonthlyTasks();
  }

  Future<void> _openDay(DateTime date) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TodoDatePage(date: date)),
    );
    await _loadMonthlyTasks();
  }

  String _timeLabel(String? t) {
    if (t == null) return '';
    try {
      final parts = t.split(':');
      final hh = int.parse(parts[0]);
      final mm = int.parse(parts[1]);
      final dt = DateTime(0, 1, 1, hh, mm);
      return DateFormat.jm().format(dt);
    } catch (_) {
      return t;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday % 7; // Sunday=0
    final days = _daysInMonth(_visibleMonth);
    final totalCells = firstWeekday + days;
    final rows = (totalCells / 7).ceil();

    final monthLabel = DateFormat.yMMMM().format(_visibleMonth);

    return Scaffold(
      appBar: AppBar(title: Text('To‑Do Calendar')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(icon: Icon(Icons.chevron_left), onPressed: _prevMonth),
                Expanded(child: Center(child: Text(monthLabel, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)))),
                IconButton(icon: Icon(Icons.chevron_right), onPressed: _nextMonth),
              ],
            ),
            SizedBox(height: 8),
            // Weekday headers
            Row(
              children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
                  .map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(fontWeight: FontWeight.w600)))))
                  .toList(),
            ),
            SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.2,
              ),
              itemCount: rows * 7,
              itemBuilder: (context, index) {
                final dayIndex = index - firstWeekday + 1;
                if (dayIndex < 1 || dayIndex > days) return Container();
                final date = DateTime(_visibleMonth.year, _visibleMonth.month, dayIndex);
                final key = _dateKey(date);
                final hasTasks = _datesWithTasks.contains(key);
                return GestureDetector(
                  onTap: () => _openDay(date),
                  child: Card(
                    color: DateTime.now().year == date.year && DateTime.now().month == date.month && DateTime.now().day == date.day
                        ? Colors.teal.shade50
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dayIndex.toString(), style: TextStyle(fontWeight: FontWeight.w600)),
                          Spacer(),
                          if (hasTasks) Align(alignment: Alignment.bottomLeft, child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle))),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 12),
            // Today's tasks area
            Card(
              child: Padding(


                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    if (_todayTasks.isEmpty) ...[
                      Text('No tasks for today.', style: TextStyle(color: Colors.grey[600])),
                    ] else ...[
                      ..._todayTasks.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final it = entry.value;
                        final txt = it['text']?.toString() ?? '';
                        final done = it['done'] == true;
                        final time = it['time']?.toString();
                        final isRec = it['recurring'] == true;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Checkbox(value: done, onChanged: (v) async {
                            if (isRec) {
                              final rid = it['rid']?.toString() ?? '';
                              await _toggleRecurringDone(rid, v == true);
                            } else {
                              // open date page to toggle
                              await _openDay(DateTime.now());
                            }
                          }),
                          title: Text(txt, style: TextStyle(decoration: done ? TextDecoration.lineThrough : TextDecoration.none)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(time != null ? _timeLabel(time) : ''),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () async {
                                  // delete recurring or one-off
                                  if (isRec) {
                                    final rid = it['rid']?.toString() ?? '';
                                    await _confirmRemoveRecurring(rid);
                                  } else {
                                    await _deleteOneOffTodayTask(idx);
                                  }
                                },
                              ),
                            ],
                          ),
                          onTap: () => _openDay(DateTime.now()),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TodoDatePage extends StatefulWidget {
  final DateTime date;
  const TodoDatePage({required this.date, super.key});

  @override
  State<TodoDatePage> createState() => _TodoDatePageState();
}

class _TodoDatePageState extends State<TodoDatePage> {
  List<Map<String, dynamic>> _tasks = []; // {text, done, recurring=false, rid?, rule?}
  final TextEditingController _controller = TextEditingController();

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  bool _recurrenceApplies(String rule, DateTime start, DateTime date) {
    if (date.isBefore(start)) return false;
    switch (rule) {
      case 'daily':
        return true;
      case 'weekly':
        return date.weekday == start.weekday;
      case 'monthly':
        return date.day == start.day;
      default:
        return false;
    }
  }

  String _key(DateTime d) => 'todos_${DateFormat('yyyy-MM-dd').format(d)}';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key(widget.date));
    // load per-date tasks
    _tasks = [];
    if (s != null) {
      try {
        final List<dynamic> list = json.decode(s);
        for (final it in list) {
          if (it is String) {
            _tasks.add({'text': it, 'done': false, 'recurring': false});
          } else if (it is Map) {
            final m = Map<String, dynamic>.from(it);
            _tasks.add({
              'text': m['text']?.toString() ?? '',
              'done': m['done'] == true,
              'recurring': false,
            });
          }
        }
      } catch (_) {
        _tasks = [];
      }
    }

    // load recurring tasks that apply to this date and mark done if in exceptions
    List<Map<String, dynamic>> recur = [];
    try {
      final rjson = prefs.getString('todos_recurring');
      if (rjson != null) {
        final List<dynamic> rl = json.decode(rjson);
        recur = rl.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    final doneListKey = 'todos_done_${_dateKey(widget.date)}';
    List<dynamic> doneList = [];
    try {
      final ds = prefs.getString(doneListKey);
      if (ds != null) doneList = json.decode(ds);
    } catch (_) {}
    for (final r in recur) {
      try {
        final start = DateTime.parse(r['start'] as String);
        final rule = (r['rule'] ?? 'none').toString();
        if (_recurrenceApplies(rule, start, widget.date)) {
          final rid = r['id']?.toString() ?? '';
          _tasks.add({
            'text': r['text']?.toString() ?? '',
            'done': doneList.contains(rid),
            'recurring': true,
            'rid': rid,
            'rule': rule,
            'start': r['start'] as String,
            'time': r['time']?.toString(),
          });
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    // persist only non-recurring tasks
    final out = _tasks.where((t) => t['recurring'] != true).map((t) => {'text': t['text'], 'done': t['done'] == true, 'time': t['time']?.toString()}).toList();
    await prefs.setString(_key(widget.date), json.encode(out));
  }

  void _addTask() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    // show recurrence options dialog
    // show recurrence + time picker dialog
    showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (c) {
        String rule = 'none';
        TimeOfDay? picked;
        return StatefulBuilder(builder: (ctx, setInner) {
          return AlertDialog(
            title: Text('Add Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: TextEditingController(text: t), readOnly: true),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: 'none',
                  items: [
                    DropdownMenuItem(value: 'none', child: Text('No recurrence')),
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (v) => setInner(() => rule = v ?? 'none'),
                  decoration: InputDecoration(labelText: 'Recurrence'),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Builder(builder: (inner) {
                      final display = picked?.format(inner) ?? 'No time';
                      return Expanded(child: Text(display));
                    }),
                    TextButton(
                      onPressed: () async {
                        final tPicked = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                        if (tPicked != null) setInner(() => picked = tPicked);
                      },
                      child: Text('Pick time'),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel')),
              TextButton(onPressed: () {
                final h = picked?.hour;
                final m = picked?.minute;
                final timeStr = (h == null || m == null) ? null : '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}';
                Navigator.pop(c, {'rule': rule, 'time': timeStr});
              }, child: Text('Save')),
            ],
          );
        });
      },
    ).then((result) async {
      if (result == null) return;
      final selectedRule = result['rule'] as String? ?? 'none';
      final selTime = result['time'] as String?;
      if (selectedRule == 'none') {
        setState(() {
          _tasks.add({'text': t, 'done': false, 'recurring': false, 'time': selTime});
          _controller.clear();
        });
        await _saveTasks();
      } else {
        // create recurring entry
        final prefs = await SharedPreferences.getInstance();
        List<Map<String, dynamic>> recur = [];
        try {
          final rjson = prefs.getString('todos_recurring');
          if (rjson != null) {
            final List<dynamic> rl = json.decode(rjson);
            recur = rl.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        } catch (_) {}
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        recur.add({'id': id, 'text': t, 'start': DateFormat('yyyy-MM-dd').format(widget.date), 'rule': selectedRule, 'time': selTime});
        await prefs.setString('todos_recurring', json.encode(recur));
        // update view
        await _loadTasks();
        _controller.clear();
      }
    });
  }

  void _editTask(int idx) async {
    final item = _tasks[idx];
    final initial = item['text']?.toString() ?? '';
    final isRec = item['recurring'] == true;
    final edited = await showDialog<String?>(
      context: context,
      builder: (c) {
        final editCtrl = TextEditingController(text: initial);
        return AlertDialog(
          title: Text(isRec ? 'Edit Recurring Task' : 'Edit Task'),
          content: TextField(controller: editCtrl, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(c, editCtrl.text.trim()), child: Text('Save')),
          ],
        );
      },
    );
    if (edited == null) return;
    if (isRec) {
      // update recurring entry
      final rid = item['rid']?.toString() ?? '';
      final prefs = await SharedPreferences.getInstance();
      try {
        final rjson = prefs.getString('todos_recurring');
        if (rjson != null) {
          final List<dynamic> rl = json.decode(rjson);
          final recur = rl.map((e) => Map<String, dynamic>.from(e)).toList();
          for (final r in recur) {
            if ((r['id']?.toString() ?? '') == rid) {
              r['text'] = edited;
              break;
            }
          }
          await prefs.setString('todos_recurring', json.encode(recur));
        }
      } catch (_) {}
      await _loadTasks();
    } else {
      setState(() {
        _tasks[idx]['text'] = edited;
      });
      await _saveTasks();
    }
  }

  void _removeTask(int idx) {
    final item = _tasks[idx];
    if (item['recurring'] == true) {
      // remove recurring entry globally
      final rid = item['rid']?.toString() ?? '';
      _confirmRemoveRecurring(rid);
      return;
    }
    setState(() {
      _tasks.removeAt(idx);
    });
    _saveTasks();
  }

  Future<void> _confirmRemoveRecurring(String rid) async {
    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove recurring task?'),
        content: Text('This will remove the recurring task for all dates.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final rjson = prefs.getString('todos_recurring');
      if (rjson != null) {
        final List<dynamic> rl = json.decode(rjson);
        final recur = rl.map((e) => Map<String, dynamic>.from(e)).where((r) => (r['id']?.toString() ?? '') != rid).toList();
        await prefs.setString('todos_recurring', json.encode(recur));
      }
    } catch (_) {}
    await _loadTasks();
  }

  Future<void> _toggleRecurringDone(String rid, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'todos_done_${_dateKey(widget.date)}';
    List<dynamic> doneList = [];
    try {
      final ds = prefs.getString(key);
      if (ds != null) doneList = json.decode(ds);
    } catch (_) {}
    if (value) {
      if (!doneList.contains(rid)) doneList.add(rid);
    } else {
      doneList.removeWhere((e) => e.toString() == rid);
    }
    await prefs.setString(key, json.encode(doneList));
    await _loadTasks();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = DateFormat.yMMMMd().format(widget.date);
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: _tasks.isEmpty
                  ? Center(child: Text('No tasks for this date.'))
                  : ListView.builder(
                      itemCount: _tasks.length,
                      itemBuilder: (context, idx) {
                        final item = _tasks[idx];
                        final text = item['text']?.toString() ?? '';
                        final done = item['done'] == true;
                        final isRec = item['recurring'] == true;
                        return Dismissible(
                          key: ValueKey(text + idx.toString()),
                          background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 16), child: Icon(Icons.delete, color: Colors.white)),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _removeTask(idx),
                          child: ListTile(
                            leading: Checkbox(value: done, onChanged: (v) async {
                              if (isRec) {
                                final rid = item['rid']?.toString() ?? '';
                                await _toggleRecurringDone(rid, v == true);
                              } else {
                                setState(() => _tasks[idx]['done'] = v == true);
                                await _saveTasks();
                              }
                            }),
                            title: Text(text, style: TextStyle(decoration: done ? TextDecoration.lineThrough : TextDecoration.none)),
                            subtitle: isRec ? Text('Recurring (${item['rule']})') : null,
                            onTap: () => _editTask(idx),
                          ),
                        );
                      },
                    ),
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: _controller, decoration: InputDecoration(hintText: 'Add a task'))),
                SizedBox(width: 8),
                ElevatedButton(onPressed: _addTask, child: Text('Add')),
              ],
            )
          ],
        ),
      ),
    );
  }
}
