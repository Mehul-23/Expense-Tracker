class Activity {
  final String type;  // e.g., "Added transaction", "Deleted category"
  final String date;
  final int amount;

  Activity({
    required this.type,
    required this.date,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'date': date,
      'amount': amount,
    };
  }

  static Activity fromMap(Map<String, dynamic> map) {
    return Activity(
      type: map['type'],
      date: map['date'],
      amount: map['amount'],
    );
  }
}
