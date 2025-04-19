import 'package:expense_tracker/activity.dart';
import 'package:expense_tracker/activityService.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  const CategoryDetailPage({
    super.key,
    required this.label,
    required this.icon,
    required transactions,
  });

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}
class _CategoryDetailPageState extends State<CategoryDetailPage> {
  List<Transaction> _transactions = [];
  double _budget = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadBudget();
  }

  void _loadTransactions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? transactionsJson = prefs.getString(widget.label);

    if (transactionsJson != null) {
      List<dynamic> transactionsList = jsonDecode(transactionsJson);
      setState(() {
        _transactions =
            transactionsList.map((tx) => Transaction.fromMap(tx)).toList();
      });
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
    setState(() {
      _budget = prefs.getDouble('${widget.label}_budget') ?? 0.0;
    });
  }

  void _saveBudget(double value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${widget.label}_budget', value);
  }

  void _addTransaction(double amount, DateTime date, String detail) async {
    setState(() {
      _transactions.add(
        Transaction(amount: amount, date: date, detail: detail),
      );
    });
    _saveTransactions();

    await ActivityService.logActivity(
      Activity(
        type: 'Added transaction in ${widget.label}',
        date: DateFormat.yMMMd().format(date),
        amount: amount.toInt(),
      ),
    );
  }

  Future<void> _deleteTransaction(int index) async {
    final deleted = _transactions[index];

    setState(() {
      _transactions.removeAt(index);
    });
    _saveTransactions();

    await ActivityService.logActivity(
      Activity(
        type: 'Deleted transaction in ${widget.label}',
        date: DateFormat.yMMMd().format(deleted.date),
        amount: -deleted.amount.toInt(),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final weeklySpendings = _calculateWeeklySpendings();
    final totalSpent = _transactions.fold(0.0, (sum, tx) => sum + tx.amount);
    final budgetLeft = _budget - totalSpent;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.label} Details')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTransactionDialog,
        child: Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Spending on ${widget.label}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups:
                      weeklySpendings
                          .asMap()
                          .entries
                          .map(
                            (e) => BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: e.value,
                                  color: Colors.green,
                                  width: 15,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(days[value.toInt() % 7]),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget:
                            (value, _) => Text('₹${value.toStringAsFixed(0)}'),
                        reservedSize: 30,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: weeklySpendings.reduce((a, b) => a > b ? a : b) + 10,
                ),
              ),
            ),
            SizedBox(height: 20),
            if (_budget > 0) ...[
              Text(
                'Budget for ${widget.label}: ₹${_budget.toStringAsFixed(0)}',
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: (totalSpent / _budget).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade300,
                color: Colors.redAccent,
                minHeight: 8,
              ),
              SizedBox(height: 4),
              Text('Remaining: ₹${budgetLeft.toStringAsFixed(0)}'),
            ] else ...[
              Text('No budget set for ${widget.label}'),
            ],
            SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                final controller = TextEditingController();
                await showDialog(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        title: Text('Set Budget for ${widget.label}'),
                        content: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Enter budget amount',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              final value = double.tryParse(controller.text);
                              if (value != null) {
                                setState(() => _budget = value);
                                _saveBudget(value);
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
            SizedBox(height: 20),
            Text(
              'Transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 10),
            Expanded(
              child:
                  _transactions.isEmpty
                      ? Center(child: Text('No transactions yet.'))
                      : ListView.builder(
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final tx = _transactions[index];
                          return ListTile(
                            leading: Icon(
                              Icons.currency_rupee,
                              color: Colors.green,
                            ),
                            title: Text(tx.detail),
                            subtitle: Text(
                              '₹${tx.amount.toStringAsFixed(2)}, ${DateFormat.yMMMd().format(tx.date)}',
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder:
                                      (ctx) => AlertDialog(
                                        title: Text('Delete Transaction?'),
                                        content: Text(
                                          'Are you sure you want to delete this transaction?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(ctx).pop(),
                                            child: Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              _deleteTransaction(index);
                                              Navigator.of(ctx).pop();
                                            },
                                            child: Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                );
                              },
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
}
