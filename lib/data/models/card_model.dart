import '../../domain/entities/card_entity.dart';

/// Data model for Card with JSON serialization
class CardModel {
  final String internalId;
  final String id;
  final String prefix;
  final String suffix;
  final String name;
  final int position;
  final double? balance;
  final DateTime? lastUpdate;

  const CardModel({
    required this.internalId,
    required this.id,
    this.prefix = '',
    this.suffix = '',
    required this.name,
    this.position = 0,
    this.balance,
    this.lastUpdate,
  });

  /// Convert to domain entity
  CardEntity toEntity() {
    return CardEntity(
      internalId: internalId,
      id: id,
      prefix: prefix,
      suffix: suffix,
      name: name,
      position: position,
      balance: balance,
      lastUpdate: lastUpdate,
    );
  }

  /// Create from domain entity
  factory CardModel.fromEntity(CardEntity entity) {
    return CardModel(
      internalId: entity.internalId,
      id: entity.id,
      prefix: entity.prefix,
      suffix: entity.suffix,
      name: entity.name,
      position: entity.position,
      balance: entity.balance,
      lastUpdate: entity.lastUpdate,
    );
  }

  /// Create from database map
  factory CardModel.fromMap(Map<String, dynamic> map) {
    return CardModel(
      internalId: map['internal_id'] as String,
      id: map['card_id'] as String,
      prefix: map['prefix'] as String? ?? '',
      suffix: map['suffix'] as String? ?? '',
      name: map['name'] as String,
      position: map['position'] as int? ?? 0,
      balance: map['balance'] as double?,
      lastUpdate: map['last_update'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_update'] as int)
          : null,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'internal_id': internalId,
      'card_id': id,
      'prefix': prefix,
      'suffix': suffix,
      'name': name,
      'position': position,
      'balance': balance,
      'last_update': lastUpdate?.millisecondsSinceEpoch,
    };
  }
}
