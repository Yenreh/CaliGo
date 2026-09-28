import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/api_exception.dart';
import '../../l10n/app_localizations.dart';
import '../providers/cards_provider.dart';
import 'lab.dart';

/// Map a typed API error to a user-friendly localized message
String cardErrorMessage(ApiException error, AppLocalizations l10n) {
  return switch (error) {
    NetworkApiException() => l10n.networkErrorMessage,
    ServerApiException() => l10n.serverErrorMessage,
    InvalidCardApiException() => l10n.invalidCardMessage,
    CardNotFoundApiException() => l10n.cardNotFoundMessage,
    RateLimitApiException() => l10n.rateLimitMessage,
    _ => l10n.couldNotUpdateBalance,
  };
}

/// Report the outcome of a balance refresh, wherever the cards are shown.
///
/// Must be called from build, like any other ref.listen.
void listenCardRefresh(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) {
  final notifier = ref.read(cardsProvider.notifier);

  ref.listen<CardsState>(cardsProvider, (previous, next) {
    final messenger = ScaffoldMessenger.of(context);

    if (next.lastRefreshSuccess && !(previous?.lastRefreshSuccess ?? false)) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        labSnackBar(
          context,
          l10n.balanceUpdated,
          tone: LabTone.ok,
          duration: const Duration(seconds: 1),
        ),
      );
    }

    if (next.refreshError != null &&
        next.refreshError != previous?.refreshError) {
      final failedCardId = next.refreshFailedCardId;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        labSnackBar(
          context,
          cardErrorMessage(next.refreshError!, l10n),
          tone: LabTone.crit,
          action: failedCardId != null
              ? SnackBarAction(
                  label: l10n.retry,
                  onPressed: () => notifier.refreshCardBalance(failedCardId),
                )
              : null,
        ),
      );
      // Clear after a beat so the snackbar is not swallowed by the rebuild
      Future.delayed(
        const Duration(milliseconds: 100),
        notifier.clearRefreshError,
      );
    }

    if (next.error != null && next.error != previous?.error) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        labSnackBar(
          context,
          l10n.couldNotUpdateBalance,
          tone: LabTone.crit,
          duration: const Duration(seconds: 2),
        ),
      );
      Future.delayed(
        const Duration(milliseconds: 100),
        notifier.clearError,
      );
    }
  });
}
