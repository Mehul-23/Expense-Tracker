import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CategoryPiePage extends StatefulWidget {
  const CategoryPiePage({super.key});

  @override
  State<CategoryPiePage> createState() => _CategoryPiePageState();
}

class _CategoryPiePageState extends State<CategoryPiePage> {
  Map<String, double> _categorySums = {};
  bool _loading = true;
  List<String> _availableMonths = [];
  String? _selectedMonth; // format YYYY-MM

  @override
  void initState() {
    super.initState();
    _loadSums();
  }

  Future<void> _loadSums() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getString('categories');
    // temporary per-month map built below
    // monthKey -> (category -> total)
    final Map<String, Map<String, double>> monthlyMap = {};

    if (categoriesJson != null) {
      try {
        final List<dynamic> cats = json.decode(categoriesJson);
        for (final c in cats) {
          final map = Map<String, dynamic>.from(c);
          final label = map['label']?.toString() ?? 'Unknown';

          // Prefer stored transactions under the category key
          final txJson = prefs.getString(label);
          if (txJson != null) {
            try {
              final List<dynamic> txs = json.decode(txJson);
              for (final t in txs) {
                try {
                  final amt = (t is Map && t['amount'] != null) ? (t['amount'] as num).toDouble() : 0.0;
                  final date = t is Map && t['date'] != null ? DateTime.parse(t['date']) : null;
                  if (date != null) {
                    final monthKey = _monthKey(date);
                    monthlyMap.putIfAbsent(monthKey, () => {});
                    monthlyMap[monthKey]![label] = (monthlyMap[monthKey]![label] ?? 0) + amt;
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
                    final date = DateTime.parse(t['date']);
                    final monthKey = _monthKey(date);
                    monthlyMap.putIfAbsent(monthKey, () => {});
                    monthlyMap[monthKey]![label] = (monthlyMap[monthKey]![label] ?? 0) + amt;
                  } catch (_) {}
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    // Persist monthlyMap as snapshot for quick access
    try {
      final snapJson = json.encode(monthlyMap.map((k, v) => MapEntry(k, v)));
      await prefs.setString('monthly_snapshots', snapJson);
    } catch (_) {}

    // prepare month selector
    final months = monthlyMap.keys.toList()..sort((a, b) => b.compareTo(a));
    final nowKey = _monthKey(DateTime.now());
    if (!months.contains(nowKey)) months.insert(0, nowKey);

    setState(() {
      _availableMonths = months;
      _selectedMonth = months.isNotEmpty ? months.first : nowKey;
      _categorySums = monthlyMap[_selectedMonth] ?? {};
      _loading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final total = _categorySums.values.fold(0.0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: Text('Category Breakdown')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Month: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedMonth,
                        items: _availableMonths.map((m) => DropdownMenuItem(value: m, child: Text(_monthLabel(m)))).toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedMonth = v;
                            // reload category sums for selected month from stored snapshots
                            _loadFromSnapshots(v);
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  if (_categorySums.isEmpty) ...[
                    Center(child: Padding(padding: EdgeInsets.only(top: 24), child: Text('No transactions to show for this month.')))
                  ] else ...[
                    AspectRatio(
                      aspectRatio: 1.3,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 4,
                              centerSpaceRadius: 36,
                              sections: _buildSections(total),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _categorySums.length,
                        itemBuilder: (context, idx) {
                          final label = _categorySums.keys.elementAt(idx);
                          final value = _categorySums.values.elementAt(idx);
                          final percent = total > 0 ? (value / total * 100) : 0.0;
                          final color = _colorsForCount(_categorySums.length)[idx];
                          return ListTile(
                            leading: CircleAvatar(backgroundColor: color, radius: 12),
                            title: Text(label),
                            trailing: Text('${value.toStringAsFixed(2)}  (${percent.toStringAsFixed(0)}%)'),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Future<void> _loadFromSnapshots(String? monthKey) async {
    if (monthKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    final snapJson = prefs.getString('monthly_snapshots');
    if (snapJson == null) {
      setState(() => _categorySums = {});
      return;
    }
    try {
      final Map<String, dynamic> all = json.decode(snapJson);
      final m = all[monthKey];
      if (m is Map) {
        final out = <String, double>{};
        m.forEach((k, v) {
          try {
            out[k] = (v as num).toDouble();
          } catch (_) {}
        });
        setState(() => _categorySums = out);
      } else {
        setState(() => _categorySums = {});
      }
    } catch (_) {
      setState(() => _categorySums = {});
    }
  }

  List<PieChartSectionData> _buildSections(double total) {
    final colors = _colorsForCount(_categorySums.length);
    final entries = _categorySums.entries.toList();
    return List.generate(entries.length, (i) {
      final e = entries[i];
      final value = e.value;
      final percent = total > 0 ? value / total * 100 : 0.0;
      return PieChartSectionData(
        color: colors[i],
        value: value,
        title: '${percent.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      );
    });
  }
}
