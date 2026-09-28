import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Ask for a label of the user's own for a stop.
///
/// Returns null when the dialog is dismissed, and the text otherwise,
/// which is empty when no label was given: the stop keeps its real name.
Future<String?> showStopNameDialog(
  BuildContext context, {
  required String title,
  required String realName,
  String? initial,
}) {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: initial ?? '');

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.customNameLabel,
              hintText: realName,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.customNameHint,
            style: Theme.of(dialogContext).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: Text(l10n.save),
        ),
      ],
    ),
  );
}
