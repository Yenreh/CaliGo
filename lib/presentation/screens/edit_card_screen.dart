import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../providers/cards_provider.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/lab.dart';

/// Screen for editing an existing card
class EditCardScreen extends ConsumerStatefulWidget {
  final String cardId;

  const EditCardScreen({super.key, required this.cardId});

  @override
  ConsumerState<EditCardScreen> createState() => _EditCardScreenState();
}

class _EditCardScreenState extends ConsumerState<EditCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _prefixController = TextEditingController();
  final _suffixController = TextEditingController();

  bool _isLoading = false;
  bool _isInitialized = false;
  String _originalId = '';

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _prefixController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  void _initControllers() {
    if (_isInitialized) return;

    final state = ref.read(cardsProvider);
    final card = state.cards.where((c) => c.id == widget.cardId).firstOrNull;

    if (card != null) {
      _nameController.text = card.name;
      _idController.text = card.id;
      _originalId = card.id;
      _prefixController.text = card.prefix;
      _suffixController.text = card.suffix;
      _isInitialized = true;
    }
  }

  String? _validateCardId(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.idRequired;
    }
    final newId = value.trim();
    if (newId == _originalId) return null;
    
    final state = ref.read(cardsProvider);
    final exists = state.cards.any((c) => c.id == newId);
    if (exists) {
      return l10n.cardIdExists;
    }
    return null;
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;

    final state = ref.read(cardsProvider);
    final card = state.cards.where((c) => c.id == widget.cardId).firstOrNull;

    if (card == null) {
      context.pop();
      return;
    }

    setState(() => _isLoading = true);

    final updatedCard = card.copyWith(
      id: _idController.text.trim(),
      name: _nameController.text.trim(),
      prefix: _prefixController.text.trim(),
      suffix: _suffixController.text.trim(),
    );

    final success = await ref
        .read(cardsProvider.notifier)
        .updateCard(updatedCard);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.pop();
      } else {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveChangesError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(cardsProvider);
    final card = state.cards.where((c) => c.id == widget.cardId).firstOrNull;

    // Initialize controllers with card data
    _initControllers();

    if (card == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: Text(l10n.editCardTitle),
        ),
        body: Center(child: Text(l10n.noCards)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.editCardTitle),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            // Card ID Section
            LabSectionLabel(l10n.cardIdLabel),
            const SizedBox(height: 8),
            TextFormField(
              controller: _idController,
              style: LabText.mono(LabPalette.of(context), size: 15),
              decoration: InputDecoration(
                hintText: l10n.cardIdPlaceholder,
                prefixIcon: const Icon(Icons.credit_card_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: (value) => _validateCardId(value, l10n),
            ),

            const SizedBox(height: 20),

            // Name Section
            LabSectionLabel(l10n.cardNameLabel),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: l10n.cardNamePlaceholder,
                prefixIcon: const Icon(Icons.label_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.nameRequired;
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Prefix Section
            LabSectionLabel(l10n.cardPrefixLabel),
            const SizedBox(height: 8),
            TextFormField(
              controller: _prefixController,
              style: LabText.mono(LabPalette.of(context), size: 15),
              decoration: InputDecoration(
                hintText: l10n.cardPrefixPlaceholder,
              ),
            ),

            const SizedBox(height: 20),

            // Suffix Section
            LabSectionLabel(l10n.cardSuffixLabel),
            const SizedBox(height: 8),
            TextFormField(
              controller: _suffixController,
              style: LabText.mono(LabPalette.of(context), size: 15),
              decoration: InputDecoration(
                hintText: l10n.cardSuffixPlaceholder,
              ),
            ),

            const SizedBox(height: 32),

            // Save button
            FilledButton(
              onPressed: _isLoading ? null : _saveCard,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: LabPalette.of(context).onFill,
                      ),
                    )
                  : Text(l10n.saveChanges),
            ),
          ],
        ),
      ),
    );
  }
}
