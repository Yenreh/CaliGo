import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_info.dart';
import '../../domain/entities/card_entity.dart';
import '../../domain/entities/stop_entity.dart';
import 'settings_provider.dart';
import 'stops_provider.dart';
import '../../data/datasources/card_remote_datasource.dart';
import '../../data/repositories/card_repository_impl.dart';
import '../../domain/repositories/card_repository.dart';

/// Provider for the card repository
final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepositoryImpl();
});

/// State class for cards list
class CardsState {
  final List<CardEntity> cards;
  final bool isLoading;
  final String? error;
  final String? refreshingCardId;
  final bool isRefreshingAll;
  final ApiException? refreshError;
  final String? refreshFailedCardId;
  final CardEntity? cardToDelete;
  final bool showDeleteDialog;
  final bool isDeletingCard;
  final bool lastRefreshSuccess;

  const CardsState({
    this.cards = const [],
    this.isLoading = false,
    this.error,
    this.refreshingCardId,
    this.isRefreshingAll = false,
    this.refreshError,
    this.refreshFailedCardId,
    this.cardToDelete,
    this.showDeleteDialog = false,
    this.isDeletingCard = false,
    this.lastRefreshSuccess = false,
  });

  CardsState copyWith({
    List<CardEntity>? cards,
    bool? isLoading,
    String? error,
    String? refreshingCardId,
    bool? isRefreshingAll,
    ApiException? refreshError,
    String? refreshFailedCardId,
    CardEntity? cardToDelete,
    bool? showDeleteDialog,
    bool? isDeletingCard,
    bool? lastRefreshSuccess,
    bool clearError = false,
    bool clearRefreshing = false,
    bool clearRefreshError = false,
    bool clearCardToDelete = false,
  }) {
    return CardsState(
      cards: cards ?? this.cards,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      refreshingCardId:
          clearRefreshing ? null : (refreshingCardId ?? this.refreshingCardId),
      isRefreshingAll: isRefreshingAll ?? this.isRefreshingAll,
      refreshError:
          clearRefreshError ? null : (refreshError ?? this.refreshError),
      refreshFailedCardId: clearRefreshError
          ? null
          : (refreshFailedCardId ?? this.refreshFailedCardId),
      cardToDelete:
          clearCardToDelete ? null : (cardToDelete ?? this.cardToDelete),
      showDeleteDialog: showDeleteDialog ?? this.showDeleteDialog,
      isDeletingCard: isDeletingCard ?? this.isDeletingCard,
      lastRefreshSuccess: lastRefreshSuccess ?? false,
    );
  }
}

/// Notifier for cards state management
class CardsNotifier extends Notifier<CardsState> {
  static const _uuid = Uuid();

  /// The refresh on opening runs once per launch, never again on coming
  /// back from the background
  bool _openRefreshDone = false;

  CardRepository get _repository => ref.read(cardRepositoryProvider);

  @override
  CardsState build() {
    // Load cards when provider is first accessed
    Future.microtask(() => loadCards());
    return const CardsState();
  }

  /// Load all cards
  Future<void> loadCards() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cards = await _repository.getAllCards();
      state = state.copyWith(cards: cards, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Create a new card
  Future<bool> createCard({
    required String id,
    required String name,
    String prefix = '',
    String suffix = '',
    int position = 0,
  }) async {
    try {
      final card = CardEntity(
        internalId: _uuid.v4(),
        id: id,
        name: name,
        prefix: prefix,
        suffix: suffix,
        position: position,
      );
      await _repository.createCard(card);
      await loadCards();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Update an existing card
  Future<bool> updateCard(CardEntity card) async {
    try {
      await _repository.updateCard(card);
      await loadCards();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Move a card as a drag leaves it, with the indexes a reorderable
  /// list reports: [newIndex] counts the card itself when moving down
  Future<void> reorderCards(int oldIndex, int newIndex) async {
    final cards = [...state.cards];
    final moved = cards.removeAt(oldIndex);
    cards.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);

    final numbered = [
      for (final (i, card) in cards.indexed) card.copyWith(position: i),
    ];
    // Shown at once; saving only follows
    state = state.copyWith(cards: numbered);

    try {
      for (final (i, card) in numbered.indexed) {
        if (cards[i].position != i) {
          await _repository.updateCard(card);
        }
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Refresh card balance from API
  Future<void> refreshCardBalance(String cardId) async {
    // Only one refresh at a time
    if (state.refreshingCardId != null) return;

    // Find the card to get full entity with prefix/suffix
    final CardEntity card;
    try {
      card = state.cards.firstWhere((c) => c.id == cardId);
    } catch (_) {
      return; // Card no longer exists
    }

    state = state.copyWith(
      refreshingCardId: cardId,
      lastRefreshSuccess: false,
      clearError: true,
      clearRefreshError: true,
    );
    try {
      final balance = await _repository.refreshCardBalance(card);
      await _repository.updateCardBalance(
          cardId, balance.balance, balance.balanceDate);
      await loadCards();
      state = state.copyWith(lastRefreshSuccess: true, clearRefreshing: true);
    } on ApiException catch (e) {
      // Keep the last known balance; flag the card as failed so the UI
      // can show the stale data notice and a typed error message.
      state = state.copyWith(
        refreshError: e,
        refreshFailedCardId: cardId,
        clearRefreshing: true,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), clearRefreshing: true);
    }
  }

  /// Refresh every balance as the app opens, once per launch, without
  /// announcing it: a card that fails only shows its balance may be out
  /// of date.
  ///
  /// Returns false while there is nothing to refresh yet, so the caller
  /// can try again once the cards have loaded.
  bool refreshOnOpen() {
    if (state.cards.isEmpty) return false;
    if (_openRefreshDone) return true;
    _openRefreshDone = true;
    if (state.isRefreshingAll || state.refreshingCardId != null) return true;

    unawaited(_refreshQuietly());
    return true;
  }

  Future<void> _refreshQuietly() async {
    state = state.copyWith(isRefreshingAll: true);
    String? failedCardId;

    // One at a time, like the manual refresh, so the service is not pressed
    for (final card in state.cards) {
      try {
        final balance = await _repository.refreshCardBalance(card);
        await _repository.updateCardBalance(
          card.id,
          balance.balance,
          balance.balanceDate,
        );
      } catch (_) {
        failedCardId ??= card.id;
      }
    }

    await loadCards();
    state = state.copyWith(
      isRefreshingAll: false,
      refreshFailedCardId: failedCardId,
      // Every card answered: nothing is out of date any more
      clearRefreshError: failedCardId == null,
    );
  }

  /// Clear the last refresh error and failed card flag
  void clearRefreshError() {
    state = state.copyWith(clearRefreshError: true);
  }

  /// Refresh every card, one at a time so the service is not hammered
  Future<void> refreshAllBalances() async {
    if (state.isRefreshingAll || state.refreshingCardId != null) return;
    if (state.cards.isEmpty) return;

    state = state.copyWith(
      isRefreshingAll: true,
      lastRefreshSuccess: false,
      clearError: true,
      clearRefreshError: true,
    );

    ApiException? failure;
    String? failedCardId;

    for (final card in state.cards) {
      try {
        final balance = await _repository.refreshCardBalance(card);
        await _repository.updateCardBalance(
          card.id,
          balance.balance,
          balance.balanceDate,
        );
      } on ApiException catch (e) {
        failure ??= e;
        failedCardId ??= card.id;
      } catch (e) {
        failure ??= ApiException(e.toString());
        failedCardId ??= card.id;
      }
    }

    await loadCards();
    state = state.copyWith(
      isRefreshingAll: false,
      refreshError: failure,
      refreshFailedCardId: failedCardId,
      lastRefreshSuccess: failure == null,
    );
  }

  /// Show delete confirmation dialog
  void showDeleteDialog(CardEntity card) {
    state = state.copyWith(cardToDelete: card, showDeleteDialog: true);
  }

  /// Hide delete dialog
  void hideDeleteDialog() {
    state = state.copyWith(showDeleteDialog: false, clearCardToDelete: true);
  }

  /// Delete card by ID directly
  Future<void> deleteCardById(String cardId) async {
    try {
      await _repository.deleteCard(cardId);
      await loadCards();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Delete card (after confirmation) - legacy method
  Future<void> deleteCard() async {
    final card = state.cardToDelete;
    if (card == null) return;

    state = state.copyWith(isDeletingCard: true);
    try {
      await _repository.deleteCard(card.id);
      state = state.copyWith(
        isDeletingCard: false,
        showDeleteDialog: false,
        clearCardToDelete: true,
      );
      await loadCards();
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isDeletingCard: false,
        showDeleteDialog: false,
      );
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Export cards, stops and settings to a JSON file, then share it
  Future<bool> exportData() async {
    try {
      final stops = ref.read(stopsProvider).favorites;

      if (state.cards.isEmpty && stops.isEmpty) {
        state = state.copyWith(error: 'No hay datos para exportar');
        return false;
      }

      final exportData = {
        'version': 4,
        'exportDate': DateTime.now().toIso8601String(),
        'cards': state.cards.map((c) => c.toJson()).toList(),
        'favoriteStops': stops.map((s) => s.toJson()).toList(),
        'settings': ref.read(settingsProvider).toJson(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/caligo_backup.json');
      await file.writeAsString(jsonString);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: '${AppInfo.name} Backup',
        ),
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al exportar: $e');
      return false;
    }
  }

  /// Restore cards, stops and settings from a backup file
  Future<int> importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return 0;
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = json.decode(jsonString) as Map<String, dynamic>;

      // Version 1 backups only carried the cards.
      final cardsList = data['cards'] as List<dynamic>? ?? const [];
      final stopsList = data['favoriteStops'] as List<dynamic>? ?? const [];
      int importedCount = 0;

      for (final cardJson in cardsList) {
        final card = CardEntity.fromJson(cardJson as Map<String, dynamic>);
        
        // Check if card with same ID already exists
        final exists = state.cards.any((c) => c.id == card.id);
        if (!exists) {
          // Generate new internal ID to avoid conflicts
          final newCard = card.copyWith(internalId: _uuid.v4());
          await _repository.createCard(newCard);
          importedCount++;
        }
      }

      final settings = data['settings'];
      if (settings is Map<String, dynamic>) {
        await ref.read(settingsProvider.notifier).importSettings(settings);
      }

      importedCount += await ref.read(stopsProvider.notifier).importFavorites(
            stopsList
                .whereType<Map<String, dynamic>>()
                .map(FavoriteStop.fromJson)
                .toList(growable: false),
          );

      await loadCards();
      return importedCount;
    } catch (e) {
      state = state.copyWith(error: 'Error al importar: $e');
      return -1;
    }
  }
}

/// Provider for cards state
final cardsProvider = NotifierProvider<CardsNotifier, CardsState>(() {
  return CardsNotifier();
});
