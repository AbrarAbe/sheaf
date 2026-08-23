import 'package:flutter/material.dart';

import '../../logic/vault_controller.dart';

/// Temporary placeholder — replaced by the real three-pane shell in Task 7.
class Shell extends StatelessWidget {
  const Shell({super.key, required this.controller});

  final VaultController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('${controller.notes.length} notes · ${controller.folders.length} folders'),
      ),
    );
  }
}
