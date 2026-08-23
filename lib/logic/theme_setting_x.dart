import 'package:flutter/material.dart';

import 'package:sheaf/models/settings.dart';

/// Maps the persisted three-way setting onto Material's theme mode.
ThemeMode toThemeMode(ThemeSetting setting) => switch (setting) {
  ThemeSetting.system => ThemeMode.system,
  ThemeSetting.light => ThemeMode.light,
  ThemeSetting.dark => ThemeMode.dark,
};

/// The next stop when cycling System → Light → Dark (`Ctrl+Shift+L`).
ThemeSetting nextThemeSetting(ThemeSetting current) => switch (current) {
  ThemeSetting.system => ThemeSetting.light,
  ThemeSetting.light => ThemeSetting.dark,
  ThemeSetting.dark => ThemeSetting.system,
};
