import 'package:caligo/data/datasources/api_exception.dart';
import 'package:caligo/domain/entities/card_balance.dart';
import 'package:caligo/domain/entities/card_entity.dart';
import 'package:caligo/domain/repositories/card_repository.dart';
import 'package:caligo/presentation/providers/cards_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cards kept in memory; the balance service fails for [failing] ids
class _FakeCardRepository implements CardRepository {
  final List<CardEntity> cards;
  final Set<String> failing;
  final List<String> asked = [];

  _FakeCardRepository(this.cards, {this.failing = const {}});

  @override
  Future<List<CardEntity>> getAllCards() async => [...cards];

  @override
  Future<CardBalance> refreshCardBalance(CardEntity card) async {
    asked.add(card.id);
    if (failing.contains(card.id)) {
      throw const ServerApiException('Proxy error', isRetryable: false);
    }
    return CardBalance(
      balance: 9000,
      cardNumber: card.id,
      balanceDate: DateTime(2026, 9, 28),
    );
  }

  @override
  Future<void> updateCardBalance(
    String id,
    double balance,
    DateTime lastUpdate,
  ) async {
    final i = cards.indexWhere((c) => c.id == id);
    cards[i] = cards[i].copyWith(balance: balance, lastUpdate: lastUpdate);
  }

  @override
  Future<CardEntity?> getCardById(String id) async =>
      cards.where((c) => c.id == id).firstOrNull;

  @override
  Future<void> createCard(CardEntity card) async => cards.add(card);

  @override
  Future<void> updateCard(CardEntity card) async {}

  @override
  Future<void> deleteCard(String id) async {}
}

CardEntity _card(String id) =>
    CardEntity(internalId: 'i$id', id: id, name: 'Card $id', balance: 100);

Future<(CardsNotifier, ProviderContainer)> _ready(
  _FakeCardRepository repository,
) async {
  final container = ProviderContainer(
    overrides: [cardRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  final notifier = container.read(cardsProvider.notifier);
  await notifier.loadCards();
  return (notifier, container);
}

/// Let the refresh started in the background run to its end
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('CardsNotifier.refreshOnOpen', () {
    test('asks for every balance without announcing it', () async {
      final repository = _FakeCardRepository([_card('a'), _card('b')]);
      final (notifier, container) = await _ready(repository);
      final announced = <bool>[];
      container.listen(
        cardsProvider,
        (_, next) => announced.add(next.lastRefreshSuccess),
      );

      expect(notifier.refreshOnOpen(), isTrue);
      await _settle();

      expect(repository.asked, ['a', 'b']);
      expect(container.read(cardsProvider).cards.map((c) => c.balance), [
        9000,
        9000,
      ]);
      expect(announced, everyElement(isFalse));
      expect(container.read(cardsProvider).isRefreshingAll, isFalse);
    });

    test('marks the card that failed as out of date, quietly', () async {
      final repository = _FakeCardRepository(
        [_card('a'), _card('b')],
        failing: {'a'},
      );
      final (notifier, container) = await _ready(repository);

      notifier.refreshOnOpen();
      await _settle();

      final state = container.read(cardsProvider);
      expect(state.refreshFailedCardId, 'a');
      // No error message: that is for refreshes the user asked for
      expect(state.refreshError, isNull);
      expect(state.cards.last.balance, 9000);
    });

    test('coming back within a few minutes does not ask again', () async {
      final repository = _FakeCardRepository([_card('a')]);
      final (notifier, _) = await _ready(repository);

      notifier.refreshOnOpen();
      await _settle();
      notifier.refreshOnOpen();
      await _settle();

      expect(repository.asked, ['a']);
    });

    test('waits for the cards before counting as done', () async {
      final repository = _FakeCardRepository([]);
      final container = ProviderContainer(
        overrides: [cardRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      expect(container.read(cardsProvider.notifier).refreshOnOpen(), isFalse);
    });
  });
}
