import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../providers/cards_provider.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/lab.dart';

/// Screen for creating a new card
class CreateCardScreen extends ConsumerStatefulWidget {
  const CreateCardScreen({super.key});

  @override
  ConsumerState<CreateCardScreen> createState() => _CreateCardScreenState();
}

class _CreateCardScreenState extends ConsumerState<CreateCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _prefixController = TextEditingController(text: '1906');
  final _suffixController = TextEditingController(text: '1');

  bool _isLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _prefixController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  Future<void> _createCard() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await ref.read(cardsProvider.notifier).createCard(
          id: _idController.text.trim(),
          name: _nameController.text.trim(),
          prefix: _prefixController.text.trim(),
          suffix: _suffixController.text.trim(),
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.pop();
      } else {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.createCardError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.createCardTitle),
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
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.idRequired;
                }
                return null;
              },
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

            // Create button
            FilledButton(
              onPressed: _isLoading ? null : _createCard,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: LabPalette.of(context).onFill,
                      ),
                    )
                  : Text(l10n.createCardButton),
            ),
          ],
        ),
      ),
    );
  }
}
