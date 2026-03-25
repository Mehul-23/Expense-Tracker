import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'category_chart_widget.dart';

class CategoryPiePage extends StatefulWidget {
  const CategoryPiePage({super.key});

  @override
  State<CategoryPiePage> createState() => _CategoryPiePageState();
}

class _CategoryPiePageState extends State<CategoryPiePage> {
  Map<String, double> _categorySums = {};
  Map<String, double> _categoryBudgets = {};
  bool _loading = true;
  List<String> _availableMonths = [];
  String? _selectedMonth;
  ChartStyle _chartStyle = ChartStyle.pie;

  @override
  void initState() {
    super.initState();
    _loadSums();
  }

  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

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

  List<Color> _colorsForCount(int count) {
    final base = [
      Colors.teal.shade600,
      Colors.green.shade600,
      Colors.blue.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.red.shade600,
      Colors.indigo.shade600,
      Colors.brown.shade600,
    ];
    return List.generate(count, (i) => base[i % base.length]);
  }

  Future<void> _loadSums() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getString('categories');
    final Map<String, Map<String, double>> monthlyMap = {};

    if (categoriesJson != null) {
      try {
        final List<dynamic> cats = json.decode(categoriesJson);
        for (final c in cats) {
          final map = Map<String, dynamic>.from(c as Map);
          final label = map['label']?.toString() ?? 'Unknown';

          final txJson = prefs.getString(label);
          if (txJson != null) {
            try {
              final List<dynamic> txs = json.decode(txJson);
              for (final t in txs) {
                try {
                  final amt = (t is Map && t['amount'] != null)
                      ? (t['amount'] as num).toDouble()
                      : 0.0;
                  final date = t is Map && t['date'] != null
                      ? DateTime.parse(t['date'] as String)
                      : null;
                  if (date != null) {
                    final mk = _monthKey(date);
                    monthlyMap.putIfAbsent(mk, () => {});
                    monthlyMap[mk]![label] =
                        (monthlyMap[mk]![label] ?? 0) + amt;
                  }
                } catch (_) {}
              }
            } catch (_) {}
          } else if (map['transactions'] is List) {
            try {
              for (final t in (map['transactions'] as List)) {
                if (t is Map && t['amount'] != null && t['date'] != null) {
                  try {
                    final amt = (t['amount'] as num).toDouble();
                    final date = DateTime.parse(t['date'] as String);
                    final mk = _monthKey(date);
                    monthlyMap.putIfAbsent(mk, () => {});
                    monthlyMap[mk]![label] =
                        (monthlyMap[mk]![label] ?? 0) + amt;
                  } catch (_) {}
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    try {
      final snapJson = json.encode(monthlyMap.map((k, v) => MapEntry(k, v)));
      await prefs.setString('monthly_snapshots', snapJson);
    } catch (_) {}

    final months = monthlyMap.keys.toList()..sort((a, b) => b.compareTo(a));
    final nowKey = _monthKey(DateTime.now());
    if (!months.contains(nowKey)) months.insert(0, nowKey);

    if (!mounted) return;
    setState(() {
      _availableMonths = months;
      _selectedMonth = months.isNotEmpty ? months.first : nowKey;
      _categorySums = monthlyMap[_selectedMonth] ?? {};
      _loading = false;
    });

    await _loadBudgetsForMonth(_selectedMonth);
  }

  Future<void> _loadBudgetsForMonth(String? monthKey) async {
    if (monthKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    final budgets = <String, double>{};
    for (final label in _categorySums.keys) {
      final budgetsJson = prefs.getString('${label}_budgets');
      double budgetForMonth = 0.0;
      if (budgetsJson != null) {
        try {
          final Map<String, dynamic> bmap = jsonDecode(budgetsJson);
          final keys = bmap.keys.toList()..sort();
          String? chosen;
          for (final k in keys) {
            if (k.compareTo(monthKey) <= 0) chosen = k;
          }
          if (chosen != null) {
            budgetForMonth = (bmap[chosen] as num).toDouble();
          }
        } catch (_) {}
      }
      budgets[label] = budgetForMonth;
    }
    if (!mounted) return;
    setState(() {
      _categoryBudgets = budgets;
    });
  }

  Future<void> _loadFromSnapshots(String? monthKey) async {
    if (monthKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    final snapJson = prefs.getString('monthly_snapshots');
    if (snapJson == null) {
      if (!mounted) return;
      setState(() {
        _categorySums = {};
        _categoryBudgets = {};
      });
      return;
    }
    try {
      final Map<String, dynamic> all = json.decode(snapJson);
      final m = all[monthKey];
      if (m is Map) {
        final out = <String, double>{};
        m.forEach((k, v) {
          try {
            out[k.toString()] = (v as num).toDouble();
          } catch (_) {}
        });
        if (!mounted) return;
        setState(() {
          _categorySums = out;
          _categoryBudgets = {};
        });
        await _loadBudgetsForMonth(monthKey);
      } else {
        if (!mounted) return;
        setState(() {
          _categorySums = {};
          _categoryBudgets = {};
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categorySums = {};
        _categoryBudgets = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _categorySums.values.fold(0.0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: const Text('Category Breakdown')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Month: ',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedMonth,
                            items: _availableMonths
                                .map((m) => DropdownMenuItem(
                                    value: m, child: Text(_monthLabel(m))))
                                .toList(),
                            onChanged: (v) async {
                              setState(() => _selectedMonth = v);
                              await _loadFromSnapshots(v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Chart Style: ',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<ChartStyle>(
                            isExpanded: true,
                            value: _chartStyle,
                            items: const [
                              DropdownMenuItem(
                                  value: ChartStyle.pie, child: Text('Pie')),
                              DropdownMenuItem(
                                  value: ChartStyle.doughnut,
                                  child: Text('Doughnut')),
                              DropdownMenuItem(
                                  value: ChartStyle.bar, child: Text('Bar')),
                              DropdownMenuItem(
                                  value: ChartStyle.polar,
                                  child: Text('Polar')),
                            ],
                            onChanged: (style) {
                              if (style != null) {
                                setState(() => _chartStyle = style);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_categorySums.isEmpty) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Text('No transactions to show for this month.'),
                        ),
                      )
                    ] else ...[
                      CategoryChartWidget(
                        data: _categorySums,
                        chartStyle: _chartStyle,
                        onChartStyleChanged: (style) =>
                            setState(() => _chartStyle = style),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_categorySums.length, (idx) {
                        final label = _categorySums.keys.elementAt(idx);
                        final value = _categorySums.values.elementAt(idx);
                        final percent =
                            total > 0 ? (value / total * 100) : 0.0;
                        final color =
                            _colorsForCount(_categorySums.length)[idx];
                        final budget = _categoryBudgets[label] ?? 0.0;
                        final budgetLeft = budget - value;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                            backgroundColor: color,
                                            radius: 10),
                                        const SizedBox(width: 8),
                                        Text(label,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    Text(
                                        '${value.toStringAsFixed(2)}  (${percent.toStringAsFixed(0)}%)'),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (budget > 0) ...[
                                  LinearProgressIndicator(
                                    value: (value / budget).clamp(0.0, 1.0),
                                    backgroundColor: Colors.grey.shade300,
                                    color: Colors.redAccent,
                                    minHeight: 8,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      'Budget: ₹${budget.toStringAsFixed(0)}   Remaining: ₹${budgetLeft.toStringAsFixed(0)}'),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
