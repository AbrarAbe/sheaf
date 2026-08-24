/// User-level app settings that persist across sessions.
///
/// Kept free of Flutter imports so the settings pipeline is testable headlessly;
/// the UI maps [theme] onto Material's `ThemeMode`.
class AppSettings {
  const AppSettings({
    this.vaultPath,
    this.theme = ThemeSetting.system,
    this.editorMode = EditorMode.normal,
    this.zoomFactor = 1.0,
    this.editorFontSize = 16.0,
    this.themeWorld = 'quire',
    this.fontFamily,
    this.fontPath,
  });

  /// Absolute path of the chosen vault folder, or null until one is picked.
  final String? vaultPath;

  final ThemeSetting theme;

  /// Which surface the editor opens in and renders right now.
  final EditorMode editorMode;

  /// App-wide text-scale multiplier. The zoom engine clamps to 0.5–2.0;
  /// stored values outside that range are clamped at point of use.
  final double zoomFactor;

  /// Base size (logical px) of editor body + preview text.
  final double editorFontSize;

  /// Id into the theme-world registry (`lib/theme`); 'quire' until more land.
  final String themeWorld;

  /// Display name of a user-selected local font. Set together with [fontPath];
  /// both null means "use the bundled stack".
  final String? fontFamily;

  /// Absolute path backing [fontFamily], loaded via FontLoader at startup.
  final String? fontPath;

  /// Note: `??` semantics mean nulls cannot be written through [copyWith];
  /// clearing the font choice constructs a new instance directly.
  AppSettings copyWith({
    String? vaultPath,
    ThemeSetting? theme,
    EditorMode? editorMode,
    double? zoomFactor,
    double? editorFontSize,
    String? themeWorld,
    String? fontFamily,
    String? fontPath,
  }) => AppSettings(
    vaultPath: vaultPath ?? this.vaultPath,
    theme: theme ?? this.theme,
    editorMode: editorMode ?? this.editorMode,
    zoomFactor: zoomFactor ?? this.zoomFactor,
    editorFontSize: editorFontSize ?? this.editorFontSize,
    themeWorld: themeWorld ?? this.themeWorld,
    fontFamily: fontFamily ?? this.fontFamily,
    fontPath: fontPath ?? this.fontPath,
  );

  Map<String, Object?> toJson() => {
    'vaultPath': vaultPath,
    'theme': theme.toJson(),
    'editorMode': editorMode.toJson(),
    'zoomFactor': zoomFactor,
    'editorFontSize': editorFontSize,
    'themeWorld': themeWorld,
    'fontFamily': fontFamily,
    'fontPath': fontPath,
  };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    vaultPath: json['vaultPath'] as String?,
    theme: ThemeSetting.fromJson(json['theme'] as String?),
    editorMode: EditorMode.fromJson(json['editorMode'] as String?),
    zoomFactor: (json['zoomFactor'] as num?)?.toDouble() ?? 1.0,
    editorFontSize: (json['editorFontSize'] as num?)?.toDouble() ?? 16.0,
    themeWorld: json['themeWorld'] as String? ?? 'quire',
    fontFamily: json['fontFamily'] as String?,
    fontPath: json['fontPath'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.vaultPath == vaultPath &&
      other.theme == theme &&
      other.editorMode == editorMode &&
      other.zoomFactor == zoomFactor &&
      other.editorFontSize == editorFontSize &&
      other.themeWorld == themeWorld &&
      other.fontFamily == fontFamily &&
      other.fontPath == fontPath;

  @override
  int get hashCode => Object.hash(
    vaultPath,
    theme,
    editorMode,
    zoomFactor,
    editorFontSize,
    themeWorld,
    fontFamily,
    fontPath,
  );
}

enum ThemeSetting {
  system,
  light,
  dark;

  String toJson() => name;

  factory ThemeSetting.fromJson(String? value) =>
      values.firstWhere((v) => v.name == value, orElse: () => ThemeSetting.system);
}

/// The three surfaces the note editor can render. See spec story 12:
/// normal = word-like editing with formatting keys, markdown = raw monospace
/// source, preview = rendered read-only.
enum EditorMode {
  normal,
  markdown,
  preview;

  String toJson() => name;

  factory EditorMode.fromJson(String? value) =>
      values.firstWhere((v) => v.name == value, orElse: () => EditorMode.normal);
}
