import '../../domain/entities/card_entity.dart';
import '../../domain/entities/card_balance.dart';
import '../../domain/repositories/card_repository.dart';
import '../datasources/card_local_datasource.dart';
import '../datasources/card_remote_datasource.dart';
import '../models/card_model.dart';

/// Implementation of CardRepository
class CardRepositoryImpl implements CardRepository {
  final CardLocalDatasource _localDatasource;
  final CardRemoteDatasource _remoteDatasource;

  CardRepositoryImpl({
    CardLocalDatasource? localDatasource,
    CardRemoteDatasource? remoteDatasource,
  })  : _localDatasource = localDatasource ?? CardLocalDatasource(),
        _remoteDatasource = remoteDatasource ?? CardRemoteDatasource();

  @override
  Future<List<CardEntity>> getAllCards() async {
    final models = await _localDatasource.getAllCards();
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<CardEntity?> getCardById(String id) async {
    final model = await _localDatasource.getCardById(id);
    return model?.toEntity();
  }

  @override
  Future<void> createCard(CardEntity card) async {
    final model = CardModel.fromEntity(card);
    await _localDatasource.insertCard(model);
  }

  @override
  Future<void> updateCard(CardEntity card) async {
    final model = CardModel.fromEntity(card);
    await _localDatasource.updateCard(model);
  }

  @override
  Future<void> deleteCard(String id) async {
    await _localDatasource.deleteCard(id);
  }

  @override
  Future<CardBalance> refreshCardBalance(CardEntity card) async {
    // Build the full card parameter: prefix + id + suffix
    final cardParam = '${card.prefix}${card.id}${card.suffix}';
    final response = await _remoteDatasource.getCardBalance(cardParam);
    return response.toEntity();
  }

  @override
  Future<void> updateCardBalance(
      String id, double balance, DateTime lastUpdate) async {
    await _localDatasource.updateCardBalance(id, balance, lastUpdate);
  }
}
