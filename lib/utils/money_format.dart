String formatMoney(int amountMinor) {
  final rupees = amountMinor ~/ 100;
  final formatted = rupees.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{2})+(\d)(?!\d))'),
    (m) => '${m[1]},',
  );
  return '₹$formatted';
}
