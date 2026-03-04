import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user theme preference and exposes it via Riverpod.
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(),
);

class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  ThemeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'dark')   state = ThemeMode.dark;
    if (saved == 'light')  state = ThemeMode.light;
    if (saved == 'system') state = ThemeMode.system;
  }

  Future<void> setDark()   => _save(ThemeMode.dark);
  Future<void> setLight()  => _save(ThemeMode.light);
  Future<void> setSystem() => _save(ThemeMode.system);

  Future<void> toggle(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await _save(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> _save(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
