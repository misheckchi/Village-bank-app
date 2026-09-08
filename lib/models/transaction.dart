class Transaction {
  final String id;
  final String title;
  final String date;
  final double amount;
  final bool isDeposit;

  Transaction({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.isDeposit,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      title: json['title'],
      date: json['date'],
      amount: (json['amount'] as num).toDouble(),
      isDeposit: json['type'] == 'deposit',
    );
  }
}
