import 'package:flutter/material.dart';

import '../../logic/vault_controller.dart';
import '../../theme/quire_theme.dart';
import '../shell/pane_widths.dart';

/// Quick filters + tags + trash. Full contents land in Task 8; this builds
/// the pane chrome (width, surface) the shell depends on.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.controller, required this.width});

  final VaultController controller;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(QuireSpace.m),
        alignment: Alignment.topLeft,
        child: Text(
          'Taker',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// The collapsed sidebar: a 64 dp icon rail (Full tier).
class Rail extends StatelessWidget {
  const Rail({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('rail'),
      width: PaneWidths.railWidth,
      child: Column(
        children: [
          IconButton(
            tooltip: 'Expand sidebar',
            onPressed: () {},
            icon: const Icon(Icons.menu_open),
          ),
        ],
      ),
    );
  }
}
