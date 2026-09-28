import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/card_entity.dart';
import '../../core/utils/date_utils.dart' as app_date;
import '../../l10n/app_localizations.dart';
import 'lab.dart';

/// Transport card as a lab panel: number, name, balance and fares
class CardItemWidget extends StatelessWidget {
  final CardEntity card;
  final bool isRefreshing;
  final bool refreshFailed;
  final int farePrice;

  /// Shorter layout, so more cards fit when the home screen also shows
  /// the favorite stops
  final bool compact;

  /// Edit and delete live in the cards screen; the dashboard only
  /// refreshes
  final bool showManageActions;
  final VoidCallback onRefreshClick;
  final VoidCallback onEditClick;
  final VoidCallback onDeleteClick;

  const CardItemWidget({
    super.key,
    required this.card,
    required this.isRefreshing,
    this.refreshFailed = false,
    required this.farePrice,
    this.compact = false,
    this.showManageActions = true,
    required this.onRefreshClick,
    required this.onEditClick,
    required this.onDeleteClick,
  });

  /// Calculate available fares
  int get availableFares {
    if (card.balance == null || card.balance! <= 0 || farePrice <= 0) return 0;
    return (card.balance! / farePrice).floor();
  }

  bool get _isStale => refreshFailed && card.balance != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = LabPalette.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (compact) return _buildCompact(context, theme, p, l10n);

    final showFares = card.balance != null && availableFares > 0;

    return LabPanel(
      accentTop: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: card number and actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatCardNumber(card.displayId),
                    style: LabText.mono(p, size: 16).copyWith(
                      letterSpacing: 1.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                LabIconButton(
                  icon: Icons.refresh_rounded,
                  isLoading: isRefreshing,
                  onPressed: onRefreshClick,
                  tooltip: l10n.updateBalance,
                ),
                if (showManageActions) ...[
                  const SizedBox(width: 6),
                  LabIconButton(
                    icon: Icons.edit_outlined,
                    onPressed: onEditClick,
                    tooltip: l10n.edit,
                  ),
                  const SizedBox(width: 6),
                  LabIconButton(
                    icon: Icons.delete_outline_rounded,
                    onPressed: onDeleteClick,
                    tooltip: l10n.delete,
                    danger: true,
                  ),
                ],
              ],
            ),
          ),
          const Divider(),

          // Name and balance
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LabSectionLabel(l10n.name),
                      const SizedBox(height: 4),
                      Text(
                        card.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 17,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    LabSectionLabel(l10n.balance),
                    const SizedBox(height: 2),
                    _BalanceDisplay(balance: card.balance),
                  ],
                ),
              ],
            ),
          ),

          // Status line: stale notice or last update, and the fares left
          if (showFares || _isStale || card.lastUpdate != null) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  Expanded(child: _statusText(p, l10n)),
                  if (showFares) ...[
                    const SizedBox(width: 12),
                    LabChip(l10n.fares(availableFares).toUpperCase()),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusText(LabPalette p, AppLocalizations l10n) {
    final style = LabText.statusLine(p).copyWith(fontSize: 13);
    if (_isStale) {
      return Text(
        l10n.staleBalanceNotice,
        style: style.copyWith(color: p.warn),
      );
    }
    if (card.lastUpdate != null) {
      return Text(
        l10n.updatedAt(app_date.DateUtils.formatDateTime(card.lastUpdate!)),
        style: style,
      );
    }
    return const SizedBox.shrink();
  }

  /// Condensed card: name, number and balance on a single row
  Widget _buildCompact(
    BuildContext context,
    ThemeData theme,
    LabPalette p,
    AppLocalizations l10n,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: p.paper,
        border: Border(
          left: BorderSide(color: _isStale ? p.warn : p.accent, width: 2),
          top: BorderSide(color: p.rule),
          right: BorderSide(color: p.rule),
          bottom: BorderSide(color: p.rule),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  card.name,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCardNumber(card.displayId),
                  style: LabText.mono(p, size: 12, color: p.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _BalanceDisplay(balance: card.balance, compact: true),
              if (card.balance != null && availableFares > 0)
                Text(
                  l10n.fares(availableFares),
                  style: LabText.mono(p, size: 11, color: p.muted),
                ),
            ],
          ),
          const SizedBox(width: 10),
          LabIconButton(
            icon: Icons.refresh_rounded,
            isLoading: isRefreshing,
            onPressed: onRefreshClick,
            tooltip: l10n.updateBalance,
          ),
        ],
      ),
    );
  }

  /// Format card number with spaces for readability
  String _formatCardNumber(String number) {
    // Remove existing spaces
    final cleaned = number.replaceAll(' ', '');
    // Add space every 4 characters
    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(cleaned[i]);
    }
    return buffer.toString();
  }
}

/// Balance in mono figures: ink when in credit, crit when overdrawn
class _BalanceDisplay extends StatelessWidget {
  final double? balance;
  final bool compact;

  const _BalanceDisplay({this.balance, this.compact = false});

  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    final size = compact ? 17.0 : 26.0;

    if (balance == null) {
      return Text('---', style: LabText.mono(p, size: size, color: p.muted));
    }

    return Text(
      _currencyFormat.format(balance),
      style: LabText.mono(
        p,
        size: size,
        color: balance! >= 0 ? p.ink : p.crit,
      ),
    );
  }
}
