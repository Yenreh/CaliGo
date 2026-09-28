import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Building blocks of the "lab report" style, shared by every screen

/// Uppercase, letter-spaced label that opens a section
class LabSectionLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const LabSectionLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    return Text(
      text.toUpperCase(),
      style: LabText.sectionLabel(p).copyWith(color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Paper panel framed by a rule, optionally opened by a 2px accent rule
class LabPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool accentTop;

  const LabPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.paper,
        border: Border.all(color: p.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (accentTop) Container(height: 2, color: p.accent),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Small outlined tag in mono type
class LabChip extends StatelessWidget {
  final String label;
  final Color? color;

  /// Shows a small filled square before the label, as a status marker
  final bool marker;

  const LabChip(this.label, {super.key, this.color, this.marker = false});

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    final tone = color ?? p.muted;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color ?? p.rule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (marker) ...[
            Container(width: 7, height: 7, color: tone),
            const SizedBox(width: 6),
          ],
          Text(label, style: LabText.mono(p, size: 12, color: tone)),
        ],
      ),
    );
  }
}

/// Bus line tag: accent outline, mono, fixed minimum width so the
/// destinations line up
class LabLineChip extends StatelessWidget {
  final String label;

  const LabLineChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 48),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: p.accent)),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: LabText.mono(p, size: 13, color: p.accent),
      ),
    );
  }
}

/// Square outlined icon button
class LabIconButton extends StatelessWidget {
  final IconData? icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool isLoading;
  final bool danger;

  /// Drawn in accent, for a toggle that is on
  final bool active;
  final double size;

  const LabIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.isLoading = false,
    this.danger = false,
    this.active = false,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    final tone = danger
        ? p.crit
        : active
            ? p.accent
            : p.muted;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.paper,
        shape: RoundedRectangleBorder(side: BorderSide(color: p.rule)),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.accent,
                      ),
                    )
                  : Icon(icon, size: 18, color: tone),
            ),
          ),
        ),
      ),
    );
  }
}

/// Square switch: rule-coloured track, filled with fill when on
class LabSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const LabSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    const duration = Duration(milliseconds: 150);

    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: duration,
          width: 40,
          height: 22,
          padding: const EdgeInsets.all(3),
          color: value ? p.fill : p.rule,
          child: AnimatedAlign(
            duration: duration,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: AnimatedContainer(
              duration: duration,
              width: 16,
              height: 16,
              color: value ? p.onFill : p.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Nothing to show yet: serif title, muted hint, optional action
class LabEmptyState extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// Outlined instead of filled, for a retry rather than a first step
  final bool secondaryAction;

  const LabEmptyState({
    super.key,
    required this.icon,
    this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.secondaryAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    final theme = Theme.of(context);

    Widget? action;
    if (actionLabel != null && onAction != null) {
      final label = Text(actionLabel!);
      action = secondaryAction
          ? OutlinedButton(onPressed: onAction, child: label)
          : actionIcon != null
              ? FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: 18),
                  label: label,
                )
              : FilledButton(onPressed: onAction, child: label);
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: p.muted.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// What a reorderable list draws under the finger while dragging: the
/// item framed in accent instead of lifted on a shadow
Widget labDragProxy(Widget child, int index, Animation<double> animation) =>
    _LabDragProxy(child: child);

class _LabDragProxy extends StatelessWidget {
  final Widget child;

  const _LabDragProxy({required this.child});

  @override
  Widget build(BuildContext context) {
    final p = LabPalette.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: p.accent, width: 2),
        ),
        child: child,
      ),
    );
  }
}

/// Tone of a snackbar, shown as a small square marker
enum LabTone { neutral, ok, warn, crit }

/// Snackbar in the lab style: paper, rule, a coloured square for the tone
SnackBar labSnackBar(
  BuildContext context,
  String message, {
  LabTone tone = LabTone.neutral,
  Duration duration = const Duration(seconds: 4),
  SnackBarAction? action,
}) {
  final p = LabPalette.of(context);
  final color = switch (tone) {
    LabTone.neutral => p.muted,
    LabTone.ok => p.ok,
    LabTone.warn => p.warn,
    LabTone.crit => p.crit,
  };

  return SnackBar(
    content: Row(
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
    duration: duration,
    action: action,
  );
}
