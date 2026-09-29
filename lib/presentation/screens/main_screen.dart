import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../providers/cards_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/card_item.dart';
import '../widgets/card_refresh_listener.dart';
import '../widgets/lab.dart';
import '../widgets/live_clock.dart';
import '../widgets/shown_on_screen.dart';
import '../widgets/favorite_stop_card.dart';
import '../providers/stops_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/app_info.dart';

/// Home dashboard: displays whatever the settings ask for.
///
/// Managing cards and stops lives in their own screens, reachable from
/// the button at the bottom.
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with ShownOnScreen {
  bool _watchingStops = false;

  /// Held so dispose does not have to reach for ref, which is unsafe
  /// once the widget is being unmounted. Read on first use: reading it
  /// starts the stops loading, which is wasted when the home screen
  /// shows only the cards.
  StopsNotifier? _stopsNotifier;

  @override
  void dispose() {
    _stopWatchingStops();
    super.dispose();
  }

  /// No polling the arrivals service in the background, or under another
  /// screen; back in view, whatever changed meanwhile is asked for
  @override
  void shownChanged(bool shown) => _syncStopsWatch();

  /// Set on opening only, not on coming back from the background; cleared
  /// once the balances have been dealt with, which waits for the settings
  /// and the cards to load
  bool _refreshBalancesPending = true;

  void _refreshBalancesIfDue() {
    if (!_refreshBalancesPending) return;
    final settings = ref.read(settingsProvider);
    if (settings.isLoading) return;
    if (!settings.refreshBalancesOnOpen || !settings.showsCards) {
      _refreshBalancesPending = false;
      return;
    }
    if (ref.read(cardsProvider).isLoading) return;
    // False until the cards are there to refresh
    if (ref.read(cardsProvider.notifier).refreshOnOpen()) {
      _refreshBalancesPending = false;
    }
  }

  void _syncStopsWatch() {
    final shouldWatch = shown && ref.read(settingsProvider).showsStops;
    if (shouldWatch == _watchingStops) return;
    if (shouldWatch) {
      _startWatchingStops();
      _stopsNotifier!.refreshArrivals();
    } else {
      _stopWatchingStops();
    }
  }

  void _startWatchingStops() {
    _watchingStops = true;
    _stopsNotifier ??= ref.read(stopsProvider.notifier);
    _stopsNotifier!.startAutoRefresh(this, homeOnly: true);
  }

  void _stopWatchingStops() {
    _watchingStops = false;
    _stopsNotifier?.stopAutoRefresh(this);
  }

  void _openStops() => context.push('/stops');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardsProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(cardsProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    final showsCards = settings.showsCards;
    final showsStops = settings.showsStops;
    // Only what the screen itself needs: the arrivals are watched by the
    // stops list alone, so a refresh does not rebuild the cards too
    final homeStopCount =
        showsStops
            ? ref.watch(
              stopsProvider.select(
                (s) => s.favorites.where((f) => f.showOnHome).length,
              ),
            )
            : 0;
    final stopsRefreshing =
        showsStops && ref.watch(stopsProvider.select((s) => s.isRefreshing));
    final showsBoth = showsCards && showsStops;
    // Condensed cards leave room for the stops below them.
    final compactCards = showsBoth && state.cards.length > 1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncStopsWatch();
      _refreshBalancesIfDue();
    });

    listenCardRefresh(context, ref, l10n);

    final isEmpty =
        (!showsCards || state.cards.isEmpty) &&
        (!showsStops || homeStopCount == 0);

    return LiveClock(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Masthead(l10n: l10n)),

              if (state.isLoading && state.cards.isEmpty && showsCards)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: LabEmptyState(
                    icon:
                        showsCards
                            ? Icons.credit_card_off_outlined
                            : Icons.signpost_outlined,
                    title: showsCards ? l10n.noCards : l10n.noFavoriteStops,
                    message:
                        showsCards
                            ? l10n.noCardsMessage
                            : l10n.noFavoriteStopsMessage,
                  ),
                )
              else ...[
                if (showsCards) ...[
                  _SectionHeader(
                    title: l10n.myCards,
                    actionLabel: l10n.seeAll,
                    onAction: () => context.push('/cards'),
                    isRefreshing: state.isRefreshingAll,
                    onRefresh: notifier.refreshAllBalances,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final card = state.cards[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: compactCards ? 8 : 12,
                          ),
                          child: CardItemWidget(
                            card: card,
                            isRefreshing: state.refreshingCardId == card.id,
                            refreshFailed: state.refreshFailedCardId == card.id,
                            farePrice: settings.farePrice,
                            compact: compactCards,
                            showManageActions: false,
                            onRefreshClick:
                                () => notifier.refreshCardBalance(card.id),
                            onEditClick: () => context.push('/cards'),
                            onDeleteClick: () => context.push('/cards'),
                          ),
                        );
                      }, childCount: state.cards.length),
                    ),
                  ),
                ],
                if (showsStops) ...[
                  _SectionHeader(
                    title: l10n.favoriteStops,
                    actionLabel: l10n.seeAll,
                    onAction: _openStops,
                    isRefreshing: stopsRefreshing,
                    onRefresh:
                        () => _stopsNotifier?.refreshArrivals(force: true),
                  ),
                  _HomeStops(l10n: l10n),
                ],
              ],
            ],
          ),
        ),
        bottomNavigationBar: _ManageBar(l10n: l10n, onStops: _openStops),
      ),
    );
  }
}

/// The favorites the home screen lists, with their arrivals
class _HomeStops extends ConsumerWidget {
  final AppLocalizations l10n;

  const _HomeStops({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stops = ref.watch(stopsProvider);
    final homeStops = stops.favorites
        .where((s) => s.showOnHome)
        .toList(growable: false);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final stop = homeStops[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FavoriteStopCard(
              stop: stop,
              arrivals: stops.arrivals[stop.id],
              isLoading: stops.isRefreshing,
              l10n: l10n,
            ),
          );
        }, childCount: homeStops.length),
      ),
    );
  }
}

/// App name over the masthead rule
class _Masthead extends StatelessWidget {
  final AppLocalizations l10n;

  const _Masthead({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = LabPalette.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.ink, width: 2)),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_bus_outlined, color: p.accent, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(AppInfo.name, style: theme.textTheme.headlineMedium),
          ),
          LabIconButton(
            icon: Icons.settings_outlined,
            onPressed: () => context.push('/settings'),
            tooltip: l10n.settings,
            size: 40,
          ),
        ],
      ),
    );
  }
}

/// Section title, with a way to refresh it and a link to its screen
class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 12, 0),
        padding: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.rule)),
        ),
        child: Row(
          children: [
            Expanded(child: LabSectionLabel(title)),
            SizedBox(
              width: 40,
              height: 40,
              child:
                  isRefreshing
                      ? Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.accent,
                          ),
                        ),
                      )
                      : IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        color: p.muted,
                        tooltip: title,
                        onPressed: onRefresh,
                      ),
            ),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

/// The two management screens with the stop search and the trip planner
/// between them, always in reach. Icons only, so all four share one size.
class _ManageBar extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onStops;

  const _ManageBar({required this.l10n, required this.onStops});

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: p.paper,
        border: Border(top: BorderSide(color: p.rule)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BarButton(
                  icon: Icons.credit_card_outlined,
                  tooltip: l10n.cardsShort,
                  onPressed: () => context.push('/cards'),
                ),
                const SizedBox(width: 8),
                _BarButton(
                  icon: Icons.search_rounded,
                  tooltip: l10n.findStops,
                  onPressed: () => context.push('/search'),
                ),
                const SizedBox(width: 8),
                _BarButton(
                  icon: Icons.directions_outlined,
                  tooltip: l10n.planTrip,
                  onPressed: () => context.push('/plan'),
                ),
                const SizedBox(width: 8),
                _BarButton(
                  icon: Icons.signpost_outlined,
                  tooltip: l10n.favoritesShort,
                  onPressed: onStops,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A bar button: an icon, named by its tooltip
class _BarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }
}
