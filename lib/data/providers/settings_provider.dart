import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import 'providers.dart';

@immutable
class AppSettings {
  const AppSettings({required this.themeMode, required this.language});
  final ThemeMode themeMode;
  final AppLanguage language;

  AppSettings copyWith({ThemeMode? themeMode, AppLanguage? language}) =>
      AppSettings(themeMode: themeMode ?? this.themeMode, language: language ?? this.language);
}

/// Theme and language, persisted in shared preferences. The language is
/// mirrored into [currentLanguage] so `tr()` works anywhere.
class SettingsNotifier extends Notifier<AppSettings> {
  static const _themeKey = 'hoglens.themeMode';
  static const _langKey = 'hoglens.language';

  @override
  AppSettings build() {
    final prefs = ref.read(storeProvider).prefs;
    final theme = ThemeMode.values.asNameMap()[prefs.getString(_themeKey) ?? ''] ?? ThemeMode.system;
    final lang = AppLanguage.values.asNameMap()[prefs.getString(_langKey) ?? ''] ?? AppLanguage.en;
    currentLanguage = lang;
    return AppSettings(themeMode: theme, language: lang);
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(storeProvider).prefs.setString(_themeKey, mode.name);
  }

  Future<void> setLanguage(AppLanguage lang) async {
    currentLanguage = lang;
    state = state.copyWith(language: lang);
    await ref.read(storeProvider).prefs.setString(_langKey, lang.name);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
