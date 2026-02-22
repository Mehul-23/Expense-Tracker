import 'package:expense_tracker/activityService.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'activity.dart';

enum DetailViewMode { week, month }

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  List<Activity> _activities = [];
  final TextEditingController _activitySearchController = TextEditingController();
  String _activityQuery = '';

  // Aggregations
  List<String> _weekKeys = []; // most-recent-first
  Map<String, List<Activity>> _weeklyMap = {};

  List<String> _monthKeys = [];
  Map<String, List<Activity>> _monthlyMap = {};

  DetailViewMode _mode = DetailViewMode.week;
  String? _selectedWeek;
  String? _selectedMonth;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadActivities();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _activitySearchController.dispose();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    final logs = await ActivityService.getActivities();
    _activities = logs;
    _buildAggregations();
    setState(() {});
  }

  void _buildAggregations() {
    _weeklyMap.clear();
    _monthlyMap.clear();

    for (final a in _activities) {
      DateTime? d;
      // try ISO parse first, then fall back to common display formats
      try {
        d = DateTime.tryParse(a.date);
      } catch (_) {
        d = null;
      }
      if (d == null) {
        try {
          d = DateFormat.yMMMd().parse(a.date);
        } catch (_) {
          // last resort: try parsing without year/month formats
          try {
            d = DateFormat.yMd().parse(a.date);
          } catch (_) {
            d = null;
          }
        }
      }
      if (d == null) continue;

      final weekKey = _weekKeyFromDate(d);
      _weeklyMap.putIfAbsent(weekKey, () => []);
      _weeklyMap[weekKey]!.add(a);

      final monthKey = _monthKey(d);
      _monthlyMap.putIfAbsent(monthKey, () => []);
      _monthlyMap[monthKey]!.add(a);
    }

    _weekKeys = _weeklyMap.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    _monthKeys = _monthlyMap.keys.toList()..sort((a, b) => b.compareTo(a));

    final nowWeek = _weekKeyFromDate(DateTime.now());
    if (!_weekKeys.contains(nowWeek)) _weekKeys.insert(0, nowWeek);

    final nowMonth = _monthKey(DateTime.now());
    if (!_monthKeys.contains(nowMonth)) _monthKeys.insert(0, nowMonth);

    _selectedWeek = _weekKeys.isNotEmpty ? _weekKeys.first : null;
    _selectedMonth = _monthKeys.isNotEmpty ? _monthKeys.first : null;

    // set initial page to 0 (most recent)
    _pageController = PageController(initialPage: 0);
  }

  String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  String _monthLabel(String key) {
    try {
      final parts = key.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return DateFormat.yMMMM().format(DateTime(y, m));
    } catch (_) {
      return key;
    }
  }

  String _weekKeyFromDate(DateTime d) {
    // compute week start (Monday)
    final start = d.subtract(Duration(days: d.weekday - 1));
    return DateFormat('yyyy-MM-dd').format(DateTime(start.year, start.month, start.day));
  }

  String _weekLabel(String weekKey) {
    try {
      final start = DateTime.parse(weekKey);
      final end = start.add(Duration(days: 6));
      return '${DateFormat.MMMd().format(start)} - ${DateFormat.MMMd().format(end)}';
    } catch (_) {
      return weekKey;
    }
  }

  void _goToPreviousWeek() {
    final page = _pageController.page?.toInt() ?? 0;
    if (page < (_weekKeys.length - 1)) _pageController.animateToPage(page + 1, duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _goToNextWeek() {
    final page = _pageController.page?.toInt() ?? 0;
    if (page > 0) _pageController.animateToPage(page - 1, duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Activity Details')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _activities.isEmpty
            ? Center(child: Text('No activity yet.'))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: TextField(
                        controller: _activitySearchController,
                        decoration: InputDecoration(
                          hintText: 'Search activities',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (v) => setState(() => _activityQuery = v),
                      ),
                    ),
                    SizedBox(height: 8),
                    // responsive toggle + month selector
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 180,
                          child: ToggleButtons(
                            isSelected: [ _mode == DetailViewMode.week, _mode == DetailViewMode.month ],
                            onPressed: (idx) {
                              setState(() {
                                _mode = idx == 0 ? DetailViewMode.week : DetailViewMode.month;
                              });
                            },
                            children: [ Padding(padding: EdgeInsets.symmetric(horizontal:12), child: Text('Week')), Padding(padding: EdgeInsets.symmetric(horizontal:12), child: Text('Month')) ],
                          ),
                        ),
                        if (_mode == DetailViewMode.month) ...[
                          Text('Month: ', style: TextStyle(fontWeight: FontWeight.w600)),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 160),
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedMonth,
                              items: _monthKeys.map((m) => DropdownMenuItem(value: m, child: Text(_monthLabel(m)))).toList(),
                              onChanged: (v) => setState(() => _selectedMonth = v),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height:12),
                    if (_mode == DetailViewMode.week) ...[
                      Row(
                        children: [
                          IconButton(icon: Icon(Icons.chevron_left), onPressed: _goToPreviousWeek),
                          Expanded(
                            child: _weekKeys.isEmpty
                                ? Center(child: Text('No weeks available'))
                                : SizedBox(
                                    height: 44,
                                    child: PageView.builder(
                                      controller: _pageController,
                                      itemCount: _weekKeys.length,
                                      onPageChanged: (index) => setState(() => _selectedWeek = _weekKeys[index]),
                                      itemBuilder: (context, index) {
                                        final key = _weekKeys[index];
                                        return Center(child: Text(_weekLabel(key), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)));
                                      },
                                    ),
                                  ),
                          ),
                          IconButton(icon: Icon(Icons.chevron_right), onPressed: _goToNextWeek),
                        ],
                      ),
                      SizedBox(height:8),
                      Builder(builder: (context) {
                        final base = _selectedWeek != null && _weeklyMap.containsKey(_selectedWeek) ? List.from(_weeklyMap[_selectedWeek]!) : [];
                        final q = _activityQuery.trim().toLowerCase();
                        final shown = q.isEmpty ? base : base.where((a) {
                          final dl = _safeDateLabel(a.date).toLowerCase();
                          return a.type.toLowerCase().contains(q) || dl.contains(q);
                        }).toList();

                        if (shown.isEmpty) return Center(child: Text('No activity for selected week.'));

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: shown.length,
                          itemBuilder: (context, idx) {
                            final a = shown[idx];
                            final dateLabel = _safeDateLabel(a.date);
                            return ListTile(
                              leading: Icon(
                                a.amount >= 0 ? Icons.add_circle : Icons.remove_circle,
                                color: a.amount >= 0 ? Colors.green : Colors.red,
                              ),
                              title: Text(a.type),
                              subtitle: Text(dateLabel),
                              trailing: Text(
                                '${a.amount > 0 ? '+' : ''}₹${a.amount}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: a.amount >= 0 ? Colors.green : Colors.red),
                              ),
                            );
                          },
                        );
                      }),
                    ] else ...[
                      // month view
                      Builder(builder: (context) {
                        final base = _selectedMonth != null && _monthlyMap.containsKey(_selectedMonth) ? List.from(_monthlyMap[_selectedMonth]!) : [];
                        final q = _activityQuery.trim().toLowerCase();
                        final shown = q.isEmpty ? base : base.where((a) {
                          final dl = _safeDateLabel(a.date).toLowerCase();
                          return a.type.toLowerCase().contains(q) || dl.contains(q);
                        }).toList();

                        if (shown.isEmpty) return Center(child: Text('No activity for selected month.'));

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: shown.length,
                          itemBuilder: (context, idx) {
                            final a = shown[idx];
                            final dateLabel = _safeDateLabel(a.date);
                            return ListTile(
                              leading: Icon(
                                a.amount >= 0 ? Icons.add_circle : Icons.remove_circle,
                                color: a.amount >= 0 ? Colors.green : Colors.red,
                              ),
                              title: Text(a.type),
                              subtitle: Text(dateLabel),
                              trailing: Text(
                                '${a.amount > 0 ? '+' : ''}₹${a.amount}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: a.amount >= 0 ? Colors.green : Colors.red),
                              ),
                            );
                          },
                        );
                      }),
                    ],
                    SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }

  String _safeDateLabel(String raw) {
    try {
      final d = DateTime.parse(raw);
      return DateFormat.yMMMd().add_jm().format(d);
    } catch (_) {
      return raw;
    }
  }
}
