import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/card_entity.dart';
import '../../l10n/app_localizations.dart';
import '../providers/cards_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/card_item.dart';
import '../widgets/card_refresh_listener.dart';
import '../widgets/lab.dart';

/// Manage the transport cards: create, refresh, edit and delete
class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardsProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(cardsProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    listenCardRefresh(context, ref, l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myCards),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (state.isRefreshingAll)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (state.cards.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: l10n.updateBalance,
              onPressed: notifier.refreshAllBalances,
            ),
        ],
      ),
      body:
          state.isLoading && state.cards.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : state.cards.isEmpty
              ? LabEmptyState(
                icon: Icons.credit_card_off_outlined,
                title: l10n.noCards,
                message: l10n.noCardsMessage,
                actionLabel: l10n.createFirstCard,
                actionIcon: Icons.add_rounded,
                onAction: () => context.push('/create'),
              )
              // Hold a card and drag it to change the order
              : ReorderableListView.builder(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  96 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: state.cards.length,
                onReorder: notifier.reorderCards,
                proxyDecorator: labDragProxy,
                itemBuilder: (context, index) {
                  final card = state.cards[index];
                  return Padding(
                    key: ValueKey(card.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CardItemWidget(
                      card: card,
                      isRefreshing: state.refreshingCardId == card.id,
                      refreshFailed: state.refreshFailedCardId == card.id,
                      farePrice: settings.farePrice,
                      onRefreshClick:
                          () => notifier.refreshCardBalance(card.id),
                      onEditClick: () => context.push('/edit/${card.id}'),
                      onDeleteClick:
                          () =>
                              _showDeleteDialog(context, notifier, card, l10n),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create'),
        tooltip: l10n.newCard,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    CardsNotifier notifier,
    CardEntity card,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (dialogContext) => _DeleteDialog(
            cardName: card.name,
            l10n: l10n,
            onConfirm: () async {
              Navigator.of(dialogContext).pop();
              await notifier.deleteCardById(card.id);
            },
            onCancel: () => Navigator.of(dialogContext).pop(),
          ),
    );
  }
}

/// Delete confirmation dialog
class _DeleteDialog extends StatelessWidget {
  final String cardName;
  final AppLocalizations l10n;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _DeleteDialog({
    required this.cardName,
    required this.l10n,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = LabPalette.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabSectionLabel(l10n.delete, color: p.crit),
            const SizedBox(height: 6),
            Text(l10n.deleteCardTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.deleteCardMessage(cardName),
              style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: p.crit,
                      foregroundColor: p.bg,
                    ),
                    child: Text(l10n.delete),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
