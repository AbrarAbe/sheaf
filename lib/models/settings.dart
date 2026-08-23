/// User-level app settings that persist across sessions.
///
/// Kept free of Flutter imports so the settings pipeline is testable headlessly;
/// the UI maps [theme] onto Material's `ThemeMode`.
class AppSettings {
  const AppSettings({this.vaultPath, this.theme = ThemeSetting.system});

  /// Absolute path of the chosen vault folder, or null until one is picked.
  final String? vaultPath;

  final ThemeSetting theme;

  AppSettings copyWith({String? vaultPath, ThemeSetting? theme}) =>
      AppSettings(vaultPath: vaultPath ?? this.vaultPath, theme: theme ?? this.theme);

  Map<String, Object?> toJson() => {'vaultPath': vaultPath, 'theme': theme.toJson()};

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    vaultPath: json['vaultPath'] as String?,
    theme: ThemeSetting.fromJson(json['theme'] as String?),
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings && other.vaultPath == vaultPath && other.theme == theme;

  @override
  int get hashCode => Object.hash(vaultPath, theme);
}

enum ThemeSetting {
  system,
  light,
  dark;

  String toJson() => name;

  factory ThemeSetting.fromJson(String? value) =>
      values.firstWhere((v) => v.name == value, orElse: () => ThemeSetting.system);
}
