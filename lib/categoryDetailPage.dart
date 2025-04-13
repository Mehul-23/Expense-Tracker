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
  final String detail; // New field for transaction detail

  Transaction({
    required this.amount,
    required this.date,
    this.detail = '',
  }); // Default value for detail

  // Convert a Transaction object to a Map
  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'date': date.toIso8601String(),
      'detail': detail, // Include detail in the map
    };
  }

  // Convert a Map to a Transaction object
  static Transaction fromMap(Map<String, dynamic> map) {
    return Transaction(
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      detail: map['detail'] ?? '', // Handle case where 'detail' might be null
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

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  // Load transactions from SharedPreferences
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

  // Save transactions to SharedPreferences
  void _saveTransactions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> transactionsList =
        _transactions.map((tx) => tx.toMap()).toList();
    String transactionsJson = jsonEncode(transactionsList);

    await prefs.setString(widget.label, transactionsJson);
  }

  void _addTransaction(double amount, DateTime date, String detail) async {
  setState(() {
    _transactions.add(
      Transaction(amount: amount, date: date, detail: detail),
    );
  });
  _saveTransactions();

  // Log activity
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
    final detailController =
        TextEditingController(); // Controller for transaction details
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
                SizedBox(height: 10),
                TextField(
                  controller:
                      detailController, // New field for transaction detail
                  decoration: InputDecoration(labelText: 'Details'),
                ),
                SizedBox(height: 10),
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
                  final detail =
                      detailController.text.trim(); // Get transaction detail
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
        final index = 6 - diff; // so that recent ones are on right
        weekly[index] += t.amount;
      }
    }
    return weekly;
  }

  @override
  Widget build(BuildContext context) {
    final weeklySpendings = _calculateWeeklySpendings();

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
                        getTitlesWidget: (value, _) {
                          return Text(
                            '₹${value.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          );
                        },
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
                  maxY:
                      weeklySpendings.reduce(
                        (value, element) => value > element ? value : element,
                      ) +
                      10,
                ),
              ),
            ),
            SizedBox(height: 30),
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
                              Icons.currency_rupee_sharp,
                              color: Colors.green,
                            ),
                            title: Text(tx.detail),
                            subtitle: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (tx.detail.isNotEmpty)
                                  Text(
                                    '₹${tx.amount.toStringAsFixed(2)}, ',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                Text(DateFormat.yMMMd().format(tx.date)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                // Optional: show a confirmation dialog before deleting
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
                                            child: Text('Cancel'),
                                            onPressed:
                                                () => Navigator.of(ctx).pop(),
                                          ),
                                          TextButton(
                                            child: Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                            onPressed: () {
                                              _deleteTransaction(index);
                                              Navigator.of(ctx).pop();
                                            },
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
