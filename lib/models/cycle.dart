import 'models.dart';

enum CycleStatus {
  active,
  settling,
  closed,
}

class Cycle {
  final String id;
  final String groupId;
  final CycleStatus status;
  final List<Expense> expenses;
  final String? startDate;
  final String? endDate;

  Cycle({
    required this.id,
    required this.groupId,
    required this.status,
    List<Expense>? expenses,
    this.startDate,
    this.endDate,
  }) : expenses = expenses ?? [];
}
