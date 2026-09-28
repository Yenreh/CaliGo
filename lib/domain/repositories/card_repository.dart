import '../entities/card_entity.dart';
import '../entities/card_balance.dart';

/// Repository interface for card operations
abstract class CardRepository {
  /// Get all cards
  Future<List<CardEntity>> getAllCards();

  /// Get a card by its ID
  Future<CardEntity?> getCardById(String id);

  /// Create a new card
  Future<void> createCard(CardEntity card);

  /// Update an existing card
  Future<void> updateCard(CardEntity card);

  /// Delete a card by its ID
  Future<void> deleteCard(String id);

  /// Refresh card balance from API
  Future<CardBalance> refreshCardBalance(CardEntity card);

  /// Update card with new balance
  Future<void> updateCardBalance(
      String id, double balance, DateTime lastUpdate);
}
