/// Card entity representing a transport card
class CardEntity {
  final String internalId;
  final String id;
  final String prefix;
  final String suffix;
  final String name;
  final int position;
  final double? balance;
  final DateTime? lastUpdate;

  const CardEntity({
    required this.internalId,
    required this.id,
    this.prefix = '',
    this.suffix = '',
    required this.name,
    this.position = 0,
    this.balance,
    this.lastUpdate,
  });

  /// Returns the display ID with prefix and suffix
  String get displayId {
    final buffer = StringBuffer();
    if (prefix.isNotEmpty) buffer.write('$prefix ');
    buffer.write(id);
    if (suffix.isNotEmpty) buffer.write(' $suffix');
    return buffer.toString();
  }

  /// Creates a copy of this card with updated fields
  CardEntity copyWith({
    String? internalId,
    String? id,
    String? prefix,
    String? suffix,
    String? name,
    int? position,
    double? balance,
    DateTime? lastUpdate,
  }) {
    return CardEntity(
      internalId: internalId ?? this.internalId,
      id: id ?? this.id,
      prefix: prefix ?? this.prefix,
      suffix: suffix ?? this.suffix,
      name: name ?? this.name,
      position: position ?? this.position,
      balance: balance ?? this.balance,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  /// Convert to JSON map for export
  Map<String, dynamic> toJson() {
    return {
      'internalId': internalId,
      'id': id,
      'prefix': prefix,
      'suffix': suffix,
      'name': name,
      'position': position,
      'balance': balance,
      'lastUpdate': lastUpdate?.toIso8601String(),
    };
  }

  /// Create from JSON map for import
  factory CardEntity.fromJson(Map<String, dynamic> json) {
    return CardEntity(
      internalId: json['internalId'] as String,
      id: json['id'] as String,
      prefix: json['prefix'] as String? ?? '',
      suffix: json['suffix'] as String? ?? '',
      name: json['name'] as String,
      position: json['position'] as int? ?? 0,
      balance: (json['balance'] as num?)?.toDouble(),
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.tryParse(json['lastUpdate'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardEntity &&
          runtimeType == other.runtimeType &&
          internalId == other.internalId;

  @override
  int get hashCode => internalId.hashCode;
}
