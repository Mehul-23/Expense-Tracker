import 'package:expense_tracker/activityService.dart';
import 'package:flutter/material.dart';
import 'activity.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  List<Activity> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  void _loadActivities() async {
    final logs = await ActivityService.getActivities();
    setState(() {
      _activities = logs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _activities.isEmpty
          ? Center(child: Text('No activity yet.'))
          : ListView.builder(
              itemCount: _activities.length,
              itemBuilder: (context, index) {
                final a = _activities[index];
                return ListTile(
                  leading: Icon(
                    a.amount >= 0 ? Icons.add_circle : Icons.remove_circle,
                    color: a.amount >= 0 ? Colors.green : Colors.red,
                  ),
                  title: Text(a.type),
                  subtitle: Text(a.date),
                  trailing: Text(
                    '${a.amount > 0 ? '+' : ''}₹${a.amount}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: a.amount >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
