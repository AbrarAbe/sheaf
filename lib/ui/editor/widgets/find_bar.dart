import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/settings.dart';
import '../../../models/shortcut_settings.dart';
import '../../../theme/quire_theme.dart';
import '../intents.dart';

class FindBar extends StatelessWidget {
  const FindBar({
    required this.controller,
    this.focusNode,
    required this.counter,
    required this.hasMatches,
    required this.onChanged,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
    this.settings,
    this.caseSensitive = false,
    this.onCaseSensitiveChanged,
  });

  final TextEditingController controller;
  final String counter;
  final bool hasMatches;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onClose;
  final AppSettings? settings;
  final FocusNode? focusNode;
  final bool caseSensitive;
  final ValueChanged<bool>? onCaseSensitiveChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overrides = settings?.shortcutOverrides ?? const {};
    SingleActivator a(ShortcutAction action) => activatorFor(action, overrides);
    return Shortcuts(
      shortcuts: {
        a(ShortcutAction.findNext): const FindNextIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter):
            const FindNextIntent(),
        a(ShortcutAction.findPrev): const FindPrevIntent(),
        a(ShortcutAction.closeFind): const CloseFindIntent(),
      },
      child: Actions(
        actions: {
          FindNextIntent: CallbackAction<FindNextIntent>(
            onInvoke: (_) => onNext(),
          ),
          FindPrevIntent: CallbackAction<FindPrevIntent>(
            onInvoke: (_) => onPrev(),
          ),
          CloseFindIntent: CallbackAction<CloseFindIntent>(
            onInvoke: (_) => onClose(),
          ),
        },
        child: Container(
          key: const Key('find-bar'),
          padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('find-field'),
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  onChanged: onChanged,
                  style: safeHanken(
                    TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Find in note…',
                    hintStyle: safeHanken(
                      TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    filled: false,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
              Text(
                counter,
                style: safeMono(
                  TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Match case',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: onCaseSensitiveChanged == null
                      ? null
                      : () => onCaseSensitiveChanged!(!caseSensitive),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: caseSensitive
                          ? theme.colorScheme.secondaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: caseSensitive
                            ? theme.colorScheme.primary.withValues(alpha: 0.3)
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Aa',
                      style: safeMono(
                        TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: caseSensitive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const Key('find-prev'),
                tooltip: 'Previous match (Shift+Enter)',
                visualDensity: VisualDensity.compact,
                onPressed: hasMatches ? onPrev : null,
                icon: const Icon(Icons.keyboard_arrow_up, size: 18),
              ),
              IconButton(
                key: const Key('find-next'),
                tooltip: 'Next match (Enter)',
                visualDensity: VisualDensity.compact,
                onPressed: hasMatches ? onNext : null,
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              ),
              IconButton(
                key: const Key('find-close'),
                tooltip: 'Close (Esc)',
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Normal / Markdown / Preview segmented control (spec story 12).
