// Shared data models for the Expenso app

class Group {
  final String id;
  final String name;
  final String status;
  final double amount;
  final String statusLine;

  Group({
    required this.id,
    required this.name,
    required this.status,
    required this.amount,
    required this.statusLine,
  });
}

class Member {
  final String id;
  final String phone;
  final String status; // 'invited' or 'joined'

  Member({
    required this.id,
    required this.phone,
    required this.status,
  });
}

class Expense {
  final String id;
  final String description;
  final double amount;
  final String date;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
  });
}

class ExpenseItem {
  final String id;
  final String description;
  final double amount;

  ExpenseItem({
    required this.id,
    required this.description,
    required this.amount,
  });
}

class HistoryCycle {
  final String id;
  final String startDate;
  final String endDate;
  final double settledAmount;
  final int expenseCount;

  HistoryCycle({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.settledAmount,
    required this.expenseCount,
  });
}
