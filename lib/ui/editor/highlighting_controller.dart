import 'package:flutter/material.dart';

/// Text controller that renders markdown formatting live in Normal mode
/// (spec story 12, feedback F4): styled spans with **dimmed markers** —
/// markers stay real characters, so selection/caret offsets are untouched.
/// Markdown mode flips [highlight] off and gets the raw monospace source.
///
/// Deliberately avoids GoogleFonts helpers here: they fetch over the network
/// on first use, which cannot happen inside a text-field paint path. Weight,
/// size, decoration, and inert family names carry the styling instead.
class HighlightingController extends TextEditingController {
  HighlightingController({super.text});

  bool highlight = false;

  static final RegExp _heading = RegExp(r'^ {0,3}(#{1,6})( +)(.*)$');
  static final RegExp _inline = RegExp(
    r'\*\*(.+?)\*\*' // bold
    r'|\*(?!\s|\*)([^*\n]+?)\*' // italic (not eating bold)
    r'|<u>(.+?)</u>' // underline
    r'|`([^`\n]+)`', // inline code
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    if (!highlight) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }

    final children = <InlineSpan>[];
    final text = this.text;
    void plain(int start, int end) {
      if (end > start) children.add(TextSpan(text: text.substring(start, end), style: base));
    }

    var lineStart = 0;
    while (lineStart <= text.length) {
      var lineEnd = text.indexOf('\n', lineStart);
      final hadBreak = lineEnd != -1;
      if (!hadBreak) lineEnd = text.length;

      final heading = _heading.firstMatch(text.substring(lineStart, lineEnd));
      if (heading != null) {
        final hashStart = lineStart + heading.start;
        final hashEnd = hashStart + heading.group(1)!.length;
        final spaceEnd = hashEnd + heading.group(2)!.length;
        final contentStart =
            lineStart + heading.start + heading.group(1)!.length + heading.group(2)!.length;
        plain(lineStart, hashStart);
        children.add(TextSpan(text: heading.group(1), style: _dim(base)));
        plain(hashEnd, spaceEnd);
        children.add(
          TextSpan(
            text: text.substring(contentStart, lineEnd),
            style: _headingStyle(base, heading.group(1)!.length),
          ),
        );
      } else {
        _emitInline(children, base, text, lineStart, lineEnd);
      }

      if (!hadBreak) break;
      plain(lineEnd, lineEnd + 1); // keep the newline glyph itself
      lineStart = lineEnd + 1;
    }

    return TextSpan(style: base, children: children);
  }

  void _emitInline(List<InlineSpan> children, TextStyle base, String text, int from, int to) {
    final region = text.substring(from, to);
    var cursor = 0;
    for (final m in _inline.allMatches(region)) {
      if (m.start > cursor) {
        children.add(TextSpan(text: region.substring(cursor, m.start), style: base));
      }
      final markerLen = _markerLen(m);
      final inner = m[1] ?? m[2] ?? m[3] ?? m[4]!;
      final innerStart = m.start + markerLen;
      final innerEnd = innerStart + inner.length;

      children.add(TextSpan(text: region.substring(m.start, innerStart), style: _dim(base)));
      children.add(TextSpan(text: inner, style: _innerStyle(base, m)));
      children.add(TextSpan(text: region.substring(innerEnd, m.end), style: _dim(base)));
      cursor = m.end;
    }
    if (region.length > cursor) {
      children.add(TextSpan(text: region.substring(cursor), style: base));
    }
  }

  int _markerLen(RegExpMatch m) {
    if (m[1] != null) return 2; // **
    if (m[2] != null) return 1; // *
    if (m[3] != null) return 3; // <u>
    return 1; // `
  }

  TextStyle _dim(TextStyle base) => base.copyWith(color: base.color?.withValues(alpha: 0.35));

  TextStyle _innerStyle(TextStyle base, RegExpMatch m) {
    if (m[1] != null) return base.copyWith(fontWeight: FontWeight.w700);
    if (m[2] != null) return base.copyWith(fontStyle: FontStyle.italic);
    if (m[3] != null) return base.copyWith(decoration: TextDecoration.underline);
    // Inline code: engine-resolved monospace; no runtime font loading.
    return base.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Spline Sans Mono', 'monospace'],
      fontSize: (base.fontSize ?? 16) - 1.5,
    );
  }

  TextStyle _headingStyle(TextStyle base, int level) {
    final size = switch (level) {
      1 => 21.0,
      2 => 18.5,
      _ => 17.0,
    };
    return base.copyWith(fontSize: size, fontWeight: FontWeight.w700, letterSpacing: -0.3);
  }
}
