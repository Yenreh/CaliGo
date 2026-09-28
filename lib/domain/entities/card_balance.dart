/// Card balance response from API
class CardBalance {
  final double balance;
  final String cardNumber;
  final DateTime balanceDate;

  const CardBalance({
    required this.balance,
    required this.cardNumber,
    required this.balanceDate,
  });
}
