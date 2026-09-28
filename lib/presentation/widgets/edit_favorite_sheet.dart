import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/stop_entity.dart';
import '../../l10n/app_localizations.dart';
import '../providers/stops_provider.dart';
import 'lab.dart';

/// What the user chose for a favorite
typedef FavoriteEdit = ({String name, List<String> lines});

/// Edit a favorite's own label and the lines it shows.
///
/// Returns null when dismissed. [seenLines] are the lines of the buses
/// already shown for it: an area favorite has no line list of its own,
/// and a stop's list may lag behind what actually passes.
Future<FavoriteEdit?> showEditFavoriteSheet(
  BuildContext context, {
  required FavoriteStop stop,
  required Iterable<String> seenLines,
}) {
  return showModalBottomSheet<FavoriteEdit>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EditFavoriteSheet(stop: stop, seenLines: seenLines),
  );
}

class _EditFavoriteSheet extends ConsumerStatefulWidget {
  final FavoriteStop stop;
  final Iterable<String> seenLines;

  const _EditFavoriteSheet({required this.stop, required this.seenLines});

  @override
  ConsumerState<_EditFavoriteSheet> createState() => _EditFavoriteSheetState();
}

class _EditFavoriteSheetState extends ConsumerState<_EditFavoriteSheet> {
  late final _name = TextEditingController(text: widget.stop.customName);
  late final Set<String> _chosen = {...widget.stop.lines};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = LabPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final stopId = widget.stop.stopId;
    final listed = stopId == null
        ? const <StopLine>[]
        : ref.watch(linesByStopProvider(stopId)).asData?.value ?? const [];

    // Every line worth offering, including any chosen that no longer
    // shows up, so it can still be taken off
    final lines = {
      for (final line in listed) line.shortName,
      ...widget.seenLines,
      ..._chosen,
    }.toList()
      ..sort();

    return Padding(
      // Keep the name field above the keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.editStop, style: theme.textTheme.titleLarge),
              const SizedBox(height: 20),
              LabSectionLabel(l10n.customNameLabel),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: widget.stop.name),
              ),
              const SizedBox(height: 6),
              Text(l10n.customNameHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: 20),
              LabSectionLabel(l10n.linesToShow),
              const SizedBox(height: 6),
              Text(l10n.linesToShowHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: 10),
              if (lines.isEmpty)
                Text(
                  l10n.noLinesForStop,
                  style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final line in lines)
                      _LineToggle(
                        label: line,
                        chosen: _chosen.contains(line),
                        onTap: () => setState(() {
                          if (!_chosen.remove(line)) _chosen.add(line);
                        }),
                      ),
                  ],
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop((
                        name: _name.text,
                        lines: _chosen.toList()..sort(),
                      )),
                      child: Text(l10n.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Line chip that can be chosen: outlined like the others, filled with
/// accent once chosen
class _LineToggle extends StatelessWidget {
  final String label;
  final bool chosen;
  final VoidCallback onTap;

  const _LineToggle({
    required this.label,
    required this.chosen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    return Semantics(
      selected: chosen,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: chosen ? p.accent : null,
            border: Border.all(color: p.accent),
          ),
          child: Text(
            label,
            style: LabText.mono(
              p,
              size: 14,
              color: chosen ? p.bg : p.accent,
            ),
          ),
        ),
      ),
    );
  }
}
