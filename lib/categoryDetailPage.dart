import 'package:expense_tracker/activity.dart';
import 'package:expense_tracker/activityService.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

enum DetailViewMode { week, month }

class Transaction {
  final double amount;
  final DateTime date;
  final String detail;

  Transaction({required this.amount, required this.date, this.detail = ''});

  Map<String, dynamic> toMap() {
    return {'amount': amount, 'date': date.toIso8601String(), 'detail': detail};
  }

  static Transaction fromMap(Map<String, dynamic> map) {
    return Transaction(
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      detail: map['detail'] ?? '',
    );
  }
}

class CategoryDetailPage extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<dynamic>? transactions;

  const CategoryDetailPage({
    super.key,
    required this.label,
    required this.icon,
    this.transactions,
  });

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}
class _CategoryDetailPageState extends State<CategoryDetailPage> {
  List<Transaction> _transactions = [];
  double _budget = 0;
  Map<String, double> _budgetHistory = {}; // effectiveMonth (yyyy-MM) -> amount
  final TextEditingController _txSearchController = TextEditingController();
  String _txQuery = '';
  // view mode
  DetailViewMode _mode = DetailViewMode.week;

  // aggregations
  List<String> _weekKeys = []; // week start keys yyyy-MM-dd (Monday)
  Map<String, List<Transaction>> _weeklyMap = {};

  List<String> _monthKeys = [];
  Map<String, List<Transaction>> _monthlyMap = {};

  String? _selectedWeek;
  String? _selectedMonth;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadTransactions();
    _loadBudget();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _txSearchController.dispose();
    super.dispose();
  }

  void _loadTransactions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? transactionsJson = prefs.getString(widget.label);
    if (transactionsJson != null) {
      List<dynamic> transactionsList = jsonDecode(transactionsJson);
      final loaded = transactionsList.map((tx) => Transaction.fromMap(tx)).toList();
      if (!mounted) return;
      setState(() {
        _transactions = loaded;
      });
      _buildAggregations();
      return;
    }

    // Fallback to transactions passed from previous screen (if any)
    if (widget.transactions != null && widget.transactions!.isNotEmpty) {
      try {
        final loaded = widget.transactions!
            .map((tx) => tx is Transaction ? tx : Transaction.fromMap(Map<String, dynamic>.from(tx)))
            .toList();
        if (!mounted) return;
        setState(() {
          _transactions = loaded;
        });
        _buildAggregations();
      } catch (_) {
        // ignore errors and leave transactions empty
      }
    }
  }

  void _saveTransactions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> transactionsList =
        _transactions.map((tx) => tx.toMap()).toList();
    String transactionsJson = jsonEncode(transactionsList);

    await prefs.setString(widget.label, transactionsJson);
  }

  void _loadBudget() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('${widget.label}_budgets');
    if (jsonStr != null) {
      try {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        _budgetHistory = map.map((k, v) => MapEntry(k, (v as num).toDouble()));
      } catch (_) {
        _budgetHistory = {};
      }
    } else {
      // migration: support old single-value key '${widget.label}_budget'
      final old = prefs.getDouble('${widget.label}_budget');
      if (old != null && old > 0) {
        final nowMonth = _monthKey(DateTime.now());
        _budgetHistory[nowMonth] = old;
        await prefs.setString('${widget.label}_budgets', jsonEncode(_budgetHistory));
      }
    }
    if (!mounted) return;
    _updateDisplayedBudget();
  }

  void _saveBudgetForMonth(String effectiveMonth, double value) async {
    // record a new effective budget starting from effectiveMonth
    _budgetHistory[effectiveMonth] = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('${widget.label}_budgets', jsonEncode(_budgetHistory));
    _updateDisplayedBudget();
  }

  double _getBudgetForMonth(String monthKey) {
    if (_budgetHistory.isEmpty) return 0.0;
    final keys = _budgetHistory.keys.toList()..sort(); // ascending
    String? chosen;
    for (final k in keys) {
      if (k.compareTo(monthKey) <= 0) chosen = k;
    }
    if (chosen == null) return 0.0;
    return _budgetHistory[chosen] ?? 0.0;
  }

  void _updateDisplayedBudget() {
    final month = (_mode == DetailViewMode.month && _selectedMonth != null) ? _selectedMonth! : _monthKey(DateTime.now());
    if (!mounted) {
      _budget = _getBudgetForMonth(month);
      return;
    }
    setState(() => _budget = _getBudgetForMonth(month));
  }

  void _addTransaction(double amount, DateTime date, String detail) async {
    setState(() {
      _transactions.add(
        Transaction(amount: amount, date: date, detail: detail),
      );
    });
    _saveTransactions();
    _buildAggregations();

    await ActivityService.logActivity(
      Activity(
        type: 'Added transaction in ${widget.label}',
        date: DateFormat.yMMMd().format(date),
        amount: amount,
      ),
    );
  }

  Future<void> _deleteTransaction(int index) async {
    final deleted = _transactions[index];

    setState(() {
      _transactions.removeAt(index);
    });
    _saveTransactions();
    _buildAggregations();

    await ActivityService.logActivity(
      Activity(
        type: 'Deleted transaction in ${widget.label}',
        date: DateFormat.yMMMd().format(deleted.date),
        amount: -deleted.amount,
      ),
    );
  }

  Future<void> _deleteTransactionInstance(Transaction tx) async {
    final idx = _transactions.indexOf(tx);
    if (idx >= 0) await _deleteTransaction(idx);
  }

  void _showAddTransactionDialog() {
    final amountController = TextEditingController();
    final detailController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Add ${widget.label} Transaction'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Amount'),
                ),
                TextField(
                  controller: detailController,
                  decoration: InputDecoration(labelText: 'Details'),
                ),
                Row(
                  children: [
                    Text('Date: ${DateFormat.yMMMd().format(selectedDate)}'),
                    Spacer(),
                    TextButton(
                      child: Text('Pick Date'),
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() => selectedDate = pickedDate);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  final detail = detailController.text.trim();
                  if (amount != null) {
                    _addTransaction(amount, selectedDate, detail);
                    Navigator.pop(context);
                  }
                },
                child: Text('Add'),
              ),
            ],
          ),
    );
  }

  List<double> _calculateWeeklySpendings() {
    // keep for backward compatibility (last 7 days)
    List<double> weekly = List.filled(7, 0.0);
    final now = DateTime.now();
    for (var t in _transactions) {
      final diff = now.difference(t.date).inDays;
      if (diff >= 0 && diff < 7) {
        final index = 6 - diff;
        weekly[index] += t.amount;
      }
    }
    return weekly;
  }

  void _buildAggregations() {
    _weeklyMap.clear();
    _monthlyMap.clear();

    for (final t in _transactions) {
      final d = t.date;
      final wk = _weekKeyFromDate(d);
      _weeklyMap.putIfAbsent(wk, () => []).add(t);

      final mk = _monthKey(d);
      _monthlyMap.putIfAbsent(mk, () => []).add(t);
    }

    _weekKeys = _weeklyMap.keys.toList()..sort((a, b) => b.compareTo(a));
    _monthKeys = _monthlyMap.keys.toList()..sort((a, b) => b.compareTo(a));

    final nowWeek = _weekKeyFromDate(DateTime.now());
    if (!_weekKeys.contains(nowWeek)) _weekKeys.insert(0, nowWeek);

    final nowMonth = _monthKey(DateTime.now());
    if (!_monthKeys.contains(nowMonth)) _monthKeys.insert(0, nowMonth);

    _selectedWeek = _weekKeys.isNotEmpty ? _weekKeys.first : null;
    _selectedMonth = _monthKeys.isNotEmpty ? _monthKeys.first : null;

    // dispose previous controller before reassigning to avoid memory leaks
    try {
      _pageController.dispose();
    } catch (_) {}
    _pageController = PageController(initialPage: 0);
    if (!mounted) return;
    setState(() {});
    _updateDisplayedBudget();
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

  List<double> _weeklyChartForWeek(String weekKey) {
    final out = List.filled(7, 0.0);
    final start = DateTime.parse(weekKey);
    for (final t in _weeklyMap[weekKey] ?? []) {
      final idx = t.date.difference(start).inDays;
      if (idx >= 0 && idx < 7) out[idx] += t.amount;
    }
    return out;
  }

  // removed unused _dailyChartForMonth to silence analyzer warning

  @override
  Widget build(BuildContext context) {
    // Always show remaining budget for the selected month (or current month if none selected)
    final currentMonthKey = _monthKey(DateTime.now());
    final selectedMonthKey = _selectedMonth ?? currentMonthKey;
    final monthlyList = _monthlyMap[selectedMonthKey] ?? [];
    final monthlyTotal = monthlyList.fold(0.0, (s, t) => s + t.amount);
    final budgetLeft = _budget - monthlyTotal;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.label} Details')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTransactionDialog,
        child: Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // View mode toggle and chart area (responsive)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: ToggleButtons(
                    isSelected: [_mode == DetailViewMode.week, _mode == DetailViewMode.month],
                    onPressed: (idx) => setState(() { _mode = idx == 0 ? DetailViewMode.week : DetailViewMode.month; _updateDisplayedBudget(); }),
                    children: [Padding(padding: EdgeInsets.symmetric(horizontal:12), child: Text('Week')), Padding(padding: EdgeInsets.symmetric(horizontal:12), child: Text('Month'))],
                  ),
                ),
                if (_mode == DetailViewMode.month) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Month: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 160),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedMonth,
                          items: _monthKeys.map((m) => DropdownMenuItem(value: m, child: Text(_monthLabel(m)))).toList(),
                          onChanged: (v) => setState(() { _selectedMonth = v; _updateDisplayedBudget(); }),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            SizedBox(height: 12),

            if (_mode == DetailViewMode.week) ...[
              Row(
                children: [
                  IconButton(icon: Icon(Icons.chevron_left), onPressed: () {
                    final page = _pageController.page?.toInt() ?? 0;
                    if (page < (_weekKeys.length - 1)) _pageController.animateToPage(page + 1, duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }),
                  Expanded(
                    child: _weekKeys.isEmpty
                        ? Center(child: Text('No weeks'))
                        : SizedBox(
                            height: 44,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _weekKeys.length,
                              onPageChanged: (index) {
                                final weekKey = _weekKeys[index];
                                final weekDate = DateTime.parse(weekKey);
                                final monthKey = _monthKey(weekDate);
                                setState(() {
                                  _selectedWeek = weekKey;
                                  _selectedMonth = monthKey;
                                  _updateDisplayedBudget();
                                });
                              },
                              itemBuilder: (context, index) {
                                final key = _weekKeys[index];
                                return Center(child: Text(_weekLabel(key), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)));
                              },
                            ),
                          ),
                  ),
                  IconButton(icon: Icon(Icons.chevron_right), onPressed: () {
                    final page = _pageController.page?.toInt() ?? 0;
                    if (page > 0) _pageController.animateToPage(page - 1, duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }),
                ],
              ),
              SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    height: 200,
                    child: Builder(
                      builder: (ctx) {
                        final data = (_selectedWeek != null && _weeklyMap.containsKey(_selectedWeek)) ? _weeklyChartForWeek(_selectedWeek!) : _calculateWeeklySpendings();
                        final double chartMax = max(data.isNotEmpty ? data.reduce((a,b) => a>b?a:b) : 0.0, 10).toDouble() + 10.0;
                        final double leftInterval = (chartMax / 4).ceilToDouble();

                        return BarChart(
                          BarChartData(
                            barGroups: data.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value, color: Theme.of(context).colorScheme.primary, width: 18, borderRadius: BorderRadius.circular(6))],),).toList(),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) { const days = ['M','T','W','T','F','S','S']; final idx = value.round() % 7; return Padding(padding: const EdgeInsets.only(top:8.0), child: Text(days[idx], style: TextStyle(fontSize:12))); },),),
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: leftInterval, reservedSize: 56, getTitlesWidget: (value, meta) => Text('₹${value.toStringAsFixed(0)}', style: TextStyle(fontSize:12)),),),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            minY: 0,
                            maxY: chartMax,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
            ] else ...[
              // month summary (no graph) - full width
              SizedBox(
                width: double.infinity,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Builder(builder: (ctx) {
                      if (_selectedMonth == null) return Center(child: Text('No month selected'));
                      final monthList = _monthlyMap[_selectedMonth] ?? [];
                      final monthlyTotal = monthList.fold(0.0, (s, t) => s + t.amount);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monthly Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          Text('₹${monthlyTotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                          SizedBox(height: 6),
                          Text('${monthList.length} transactions', style: TextStyle(color: Colors.grey[700])),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Budget for ${widget.label} (${_monthLabel(selectedMonthKey)})', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(_budget > 0 ? '₹${_budget.toStringAsFixed(0)}' : 'No budget', style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (_budget > 0) ...[
                      LinearProgressIndicator(
                        value: (_budget > 0) ? (monthlyTotal / _budget).clamp(0.0, 1.0) : 0.0,
                        backgroundColor: Colors.grey.shade300,
                        color: Colors.redAccent,
                        minHeight: 8,
                      ),
                      SizedBox(height: 8),
                      Text('Remaining: ₹${budgetLeft.toStringAsFixed(0)}'),
                    ],
                    SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final effectiveMonth = (_mode == DetailViewMode.month && _selectedMonth != null)
                              ? _selectedMonth!
                              : _monthKey(DateTime.now());
                          final controller = TextEditingController();
                          final existing = _getBudgetForMonth(effectiveMonth);
                          controller.text = (existing > 0) ? existing.toStringAsFixed(0) : '';
                          await showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text('Set Budget for ${widget.label}'),
                              content: TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: 'Enter budget amount'),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                                TextButton(
                                  onPressed: () {
                                    final value = double.tryParse(controller.text);
                                    if (value != null) {
                                      _saveBudgetForMonth(effectiveMonth, value);
                                    }
                                    Navigator.pop(context);
                                  },
                                  child: Text('Set'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: Icon(Icons.account_balance_wallet),
                        label: Text('Set Budget'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextField(
                controller: _txSearchController,
                decoration: InputDecoration(
                  hintText: 'Search transactions',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) => setState(() => _txQuery = v),
              ),
            ),
            SizedBox(height: 12),
            Text('Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Builder(builder: (context) {
              final List<Transaction> filtered;
              if (_mode == DetailViewMode.week) {
                filtered = _selectedWeek != null && _weeklyMap.containsKey(_selectedWeek)
                    ? List<Transaction>.from(_weeklyMap[_selectedWeek]!)
                    : <Transaction>[];
              } else if (_mode == DetailViewMode.month) {
                filtered = _selectedMonth != null && _monthlyMap.containsKey(_selectedMonth)
                    ? List<Transaction>.from(_monthlyMap[_selectedMonth]!)
                    : <Transaction>[];
              } else {
                filtered = _transactions;
              }

              final query = _txQuery.trim().toLowerCase();
              final shown = query.isEmpty
                  ? filtered
                  : filtered.where((t) => t.detail.toLowerCase().contains(query) || DateFormat.yMMMd().format(t.date).toLowerCase().contains(query)).toList();

              if (shown.isEmpty) return Center(child: Text('No transactions yet.'));

              return ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: shown.length,
                separatorBuilder: (_, __) => SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final tx = shown[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withAlpha((0.12 * 255).round()),
                        child: Icon(Icons.currency_rupee, color: Theme.of(context).colorScheme.primary),
                      ),
                      title: Text(tx.detail.isNotEmpty ? tx.detail : widget.label),
                      subtitle: Text(DateFormat.yMMMd().format(tx.date)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${tx.amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w700)),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('Delete Transaction?'),
                                  content: Text('Are you sure you want to delete this transaction?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel')),
                                    TextButton(
                                      onPressed: () {
                                        _deleteTransactionInstance(tx);
                                        Navigator.of(ctx).pop();
                                      },
                                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
