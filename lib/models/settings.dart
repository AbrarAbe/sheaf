/// User-level app settings that persist across sessions.
///
/// Kept free of Flutter imports so the settings pipeline is testable headlessly;
/// the UI maps [theme] onto Material's `ThemeMode`.
class AppSettings {
  const AppSettings({
    this.vaultPath,
    this.vaultPaths,
    this.theme = ThemeSetting.system,
    this.editorMode = EditorMode.normal,
    this.zoomFactor = 1.0,
    this.editorFontSize = 16.0,
    this.themeWorld = 'quire',
    this.sidebarExpanded = true,
    this.sidebarFull = false,
    this.sidebarStack = false,
    this.showWindowControls = true,
    this.shortcutOverrides = const {},
  });

  /// Absolute path of the chosen vault folder, or null until one is picked.
  final String? vaultPath;

  /// Multi-vault support: ordered list of vault roots, primary = [0].
  final List<String>? vaultPaths;

  List<String> get effectiveVaultPaths {
    if (vaultPaths != null && vaultPaths!.isNotEmpty) return vaultPaths!;
    if (vaultPath != null) return [vaultPath!];
    return const [];
  }

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

  /// Per-tier sidebar visibility (spec story 15). Defaults mirror the
  /// historical layout: expanded shows the pane, narrower tiers start hidden.
  final bool sidebarExpanded;
  final bool sidebarFull;
  final bool sidebarStack;

  /// Whether the header shows the functional traffic-light window controls
  /// (v0.3). Some setups keep the compositor title bar and want them gone.
  final bool showWindowControls;

  /// Customizable shortcut overrides: action name to serialized `SingleActivator`.
  /// Empty means all defaults apply. Stored as `Map<String,String>` to keep this
  /// file Flutter-free; parsing lives in shortcut_serializer.dart.
  final Map<String, String> shortcutOverrides;

  /// Note: `??` semantics mean nulls cannot be written through [copyWith].
  AppSettings copyWith({
    String? vaultPath,
    List<String>? vaultPaths,
    ThemeSetting? theme,
    EditorMode? editorMode,
    double? zoomFactor,
    double? editorFontSize,
    String? themeWorld,
    bool? sidebarExpanded,
    bool? sidebarFull,
    bool? sidebarStack,
    bool? showWindowControls,
    Map<String, String>? shortcutOverrides,
  }) => AppSettings(
    vaultPath: vaultPath ?? this.vaultPath,
    vaultPaths: vaultPaths ?? this.vaultPaths,
    theme: theme ?? this.theme,
    editorMode: editorMode ?? this.editorMode,
    zoomFactor: zoomFactor ?? this.zoomFactor,
    editorFontSize: editorFontSize ?? this.editorFontSize,
    themeWorld: themeWorld ?? this.themeWorld,
    sidebarExpanded: sidebarExpanded ?? this.sidebarExpanded,
    sidebarFull: sidebarFull ?? this.sidebarFull,
    sidebarStack: sidebarStack ?? this.sidebarStack,
    showWindowControls: showWindowControls ?? this.showWindowControls,
    shortcutOverrides: shortcutOverrides ?? this.shortcutOverrides,
  );

  Map<String, Object?> toJson() => {
    'vaultPath': vaultPath,
    'vaultPaths': vaultPaths,
    'theme': theme.toJson(),
    'editorMode': editorMode.toJson(),
    'zoomFactor': zoomFactor,
    'editorFontSize': editorFontSize,
    'themeWorld': themeWorld,
    'sidebarExpanded': sidebarExpanded,
    'sidebarFull': sidebarFull,
    'sidebarStack': sidebarStack,
    'showWindowControls': showWindowControls,
    if (shortcutOverrides.isNotEmpty) 'shortcutOverrides': shortcutOverrides,
  };
  factory AppSettings.fromJson(Map<String, Object?> json) {
    List<String>? vps;
    final rawVps = json['vaultPaths'];
    if (rawVps is List) {
      vps = rawVps.whereType<String>().toList();
      if (vps.isEmpty) vps = null;
      // Normalize single vault stored as vaultPaths to null for equality
      // with legacy AppSettings(vaultPath: ...) that had vaultPaths null.
      final legacySingle = json['vaultPath'] as String?;
      if (vps != null && vps.length == 1 && vps[0] == legacySingle) vps = null;
    }
    final legacy = json['vaultPath'] as String?;
    if (vps == null && legacy != null) {
      // Keep vaultPaths null for single vault to preserve round-trip equality;
      // effectiveVaultPaths will still return [legacy].
      vps = null;
    }
    Map<String, String> overrides = const {};
    final rawOverrides = json['shortcutOverrides'];
    if (rawOverrides is Map) {
      overrides = {
        for (final e in rawOverrides.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      };
    }
    return AppSettings(
      vaultPath: legacy,
      vaultPaths: vps,
      theme: ThemeSetting.fromJson(json['theme'] as String?),
      editorMode: EditorMode.fromJson(json['editorMode'] as String?),
      zoomFactor: (json['zoomFactor'] as num?)?.toDouble() ?? 1.0,
      editorFontSize: (json['editorFontSize'] as num?)?.toDouble() ?? 16.0,
      themeWorld: json['themeWorld'] as String? ?? 'quire',
      sidebarExpanded: json['sidebarExpanded'] as bool? ?? true,
      sidebarFull: json['sidebarFull'] as bool? ?? false,
      sidebarStack: json['sidebarStack'] as bool? ?? false,
      showWindowControls: json['showWindowControls'] as bool? ?? true,
      shortcutOverrides: overrides,
    );
  }
  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.vaultPath == vaultPath &&
      _listEq(other.vaultPaths, vaultPaths) &&
      other.theme == theme &&
      other.editorMode == editorMode &&
      other.zoomFactor == zoomFactor &&
      other.editorFontSize == editorFontSize &&
      other.themeWorld == themeWorld &&
      other.sidebarExpanded == sidebarExpanded &&
      other.sidebarFull == sidebarFull &&
      other.sidebarStack == sidebarStack &&
      other.showWindowControls == showWindowControls &&
      _mapEq(other.shortcutOverrides, shortcutOverrides);

  @override
  int get hashCode => Object.hash(
    vaultPath,
    Object.hashAll(vaultPaths ?? const []),
    theme,
    editorMode,
    zoomFactor,
    editorFontSize,
    themeWorld,
    sidebarExpanded,
    sidebarFull,
    sidebarStack,
    showWindowControls,
    Object.hashAllUnordered(
      shortcutOverrides.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

bool _mapEq(Map<String, String> a, Map<String, String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

bool _listEq(List<String>? a, List<String>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

enum ThemeSetting {
  system,
  light,
  dark;

  String toJson() => name;

  factory ThemeSetting.fromJson(String? value) => values.firstWhere(
    (v) => v.name == value,
    orElse: () => ThemeSetting.system,
  );
}

/// The three surfaces the note editor can render. See spec story 12:
/// normal = word-like editing with formatting keys, markdown = raw monospace
/// source, preview = rendered read-only.
enum EditorMode {
  normal,
  markdown,
  preview;

  String toJson() => name;

  factory EditorMode.fromJson(String? value) => values.firstWhere(
    (v) => v.name == value,
    orElse: () => EditorMode.normal,
  );
}

/// Window layout tier (spec story 15). Lives beside settings so per-tier
/// visibility flags can be keyed by tier without a ui→models dependency.
enum WindowTier { expanded, full, stack }
