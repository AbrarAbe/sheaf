import 'package:flutter/material.dart';

import '../../logic/vault_controller.dart';
import '../../theme/quire_theme.dart';

/// The note list pane. Full contents (filter, sort, day grouping) land in
/// Task 9; this builds the pane chrome the shell depends on.
class ListPane extends StatelessWidget {
  const ListPane({super.key, required this.controller});

  final VaultController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(QuireSpace.xl),
      alignment: Alignment.topLeft,
      child: Text(
        'Nothing here yet.',
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
