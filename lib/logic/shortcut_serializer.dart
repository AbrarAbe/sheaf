import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Serializes a [SingleActivator] to a portable string like `Ctrl+Shift+K`.
String serializeActivator(SingleActivator activator) {
  final parts = <String>[];
  if (activator.control) parts.add('Ctrl');
  if (activator.alt) parts.add('Alt');
  if (activator.shift) parts.add('Shift');
  if (activator.meta) parts.add('Meta');
  parts.add(_keyToString(activator.trigger));
  return parts.join('+');
}

/// Tries to parse a string produced by [serializeActivator] back to a
/// [SingleActivator]. Returns `null` on invalid input.
SingleActivator? tryParseActivator(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final tokens = trimmed.split('+');
  if (tokens.isEmpty) return null;
  bool control = false;
  bool alt = false;
  bool shift = false;
  bool meta = false;
  for (var i = 0; i < tokens.length - 1; i++) {
    final m = tokens[i].trim().toLowerCase();
    switch (m) {
      case 'ctrl':
      case 'control':
        control = true;
        break;
      case 'alt':
        alt = true;
        break;
      case 'shift':
        shift = true;
        break;
      case 'meta':
      case 'cmd':
      case 'super':
        meta = true;
        break;
      default:
        return null;
    }
  }
  final keyToken = tokens.last.trim();
  final key = _stringToKey(keyToken);
  if (key == null) return null;
  return SingleActivator(
    key,
    control: control,
    alt: alt,
    shift: shift,
    meta: meta,
  );
}

String _keyToString(LogicalKeyboardKey key) {
  final mapped = _keyToLabel[key];
  if (mapped != null) return mapped;
  if (key.keyLabel.isNotEmpty) return key.keyLabel;
  return key.debugName ?? key.keyId.toString();
}

LogicalKeyboardKey? _stringToKey(String token) {
  if (token.isEmpty) return null;
  final lower = token.toLowerCase();
  const aliases = <String, String>{
    'del': 'delete',
    'esc': 'escape',
    'return': 'enter',
  };
  final norm = aliases[lower] ?? lower;
  for (final entry in _keyToLabel.entries) {
    if (entry.value.toLowerCase() == norm) return entry.key;
    if (entry.value.length == 1 && entry.value.toLowerCase() == norm)
      return entry.key;
  }
  if (token.length == 1) {
    final upper = token.toUpperCase();
    if (upper.codeUnitAt(0) >= 65 && upper.codeUnitAt(0) <= 90) {
      final id = LogicalKeyboardKey.keyA.keyId + (upper.codeUnitAt(0) - 65);
      for (final e in _keyToLabel.entries) {
        if (e.key.keyId == id) return e.key;
      }
    }
  }
  return null;
}

final _keyToLabel = <LogicalKeyboardKey, String>{
  LogicalKeyboardKey.keyA: 'A',
  LogicalKeyboardKey.keyB: 'B',
  LogicalKeyboardKey.keyC: 'C',
  LogicalKeyboardKey.keyD: 'D',
  LogicalKeyboardKey.keyE: 'E',
  LogicalKeyboardKey.keyF: 'F',
  LogicalKeyboardKey.keyG: 'G',
  LogicalKeyboardKey.keyH: 'H',
  LogicalKeyboardKey.keyI: 'I',
  LogicalKeyboardKey.keyJ: 'J',
  LogicalKeyboardKey.keyK: 'K',
  LogicalKeyboardKey.keyL: 'L',
  LogicalKeyboardKey.keyM: 'M',
  LogicalKeyboardKey.keyN: 'N',
  LogicalKeyboardKey.keyO: 'O',
  LogicalKeyboardKey.keyP: 'P',
  LogicalKeyboardKey.keyQ: 'Q',
  LogicalKeyboardKey.keyR: 'R',
  LogicalKeyboardKey.keyS: 'S',
  LogicalKeyboardKey.keyT: 'T',
  LogicalKeyboardKey.keyU: 'U',
  LogicalKeyboardKey.keyV: 'V',
  LogicalKeyboardKey.keyW: 'W',
  LogicalKeyboardKey.keyX: 'X',
  LogicalKeyboardKey.keyY: 'Y',
  LogicalKeyboardKey.keyZ: 'Z',
  LogicalKeyboardKey.digit0: '0',
  LogicalKeyboardKey.digit1: '1',
  LogicalKeyboardKey.digit2: '2',
  LogicalKeyboardKey.digit3: '3',
  LogicalKeyboardKey.digit4: '4',
  LogicalKeyboardKey.digit5: '5',
  LogicalKeyboardKey.digit6: '6',
  LogicalKeyboardKey.digit7: '7',
  LogicalKeyboardKey.digit8: '8',
  LogicalKeyboardKey.digit9: '9',
  LogicalKeyboardKey.f1: 'F1',
  LogicalKeyboardKey.f2: 'F2',
  LogicalKeyboardKey.f3: 'F3',
  LogicalKeyboardKey.f4: 'F4',
  LogicalKeyboardKey.f5: 'F5',
  LogicalKeyboardKey.f6: 'F6',
  LogicalKeyboardKey.f7: 'F7',
  LogicalKeyboardKey.f8: 'F8',
  LogicalKeyboardKey.f9: 'F9',
  LogicalKeyboardKey.f10: 'F10',
  LogicalKeyboardKey.f11: 'F11',
  LogicalKeyboardKey.f12: 'F12',
  LogicalKeyboardKey.enter: 'Enter',
  LogicalKeyboardKey.numpadEnter: 'NumpadEnter',
  LogicalKeyboardKey.escape: 'Esc',
  LogicalKeyboardKey.delete: 'Del',
  LogicalKeyboardKey.backspace: 'Backspace',
  LogicalKeyboardKey.tab: 'Tab',
  LogicalKeyboardKey.space: 'Space',
  LogicalKeyboardKey.equal: '=',
  LogicalKeyboardKey.minus: '-',
  LogicalKeyboardKey.slash: '/',
  LogicalKeyboardKey.backslash: r'\',
  LogicalKeyboardKey.bracketLeft: '[',
  LogicalKeyboardKey.bracketRight: ']',
  LogicalKeyboardKey.comma: ',',
  LogicalKeyboardKey.period: '.',
  LogicalKeyboardKey.semicolon: ';',
  LogicalKeyboardKey.quote: "'",
  LogicalKeyboardKey.backquote: '`',
  LogicalKeyboardKey.add: 'Add',
  LogicalKeyboardKey.numpadSubtract: 'NumpadSubtract',
  LogicalKeyboardKey.numpadAdd: 'NumpadAdd',
};
