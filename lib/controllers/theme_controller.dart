import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';

/// App-wide theme mode (light / dark / system), persisted in SharedPreferences.
/// Live switching uses `Get.changeThemeMode`, which GetMaterialApp reacts to.
class ThemeController extends GetxController {
  ThemeController(this._prefs);

  final SharedPreferences _prefs;

  final Rx<ThemeMode> mode = ThemeMode.system.obs;

  /// Reads the saved mode into memory (call once at startup).
  ThemeMode load() {
    mode.value = _parse(_prefs.getString(StorageKeys.themeMode));
    return mode.value;
  }

  bool get isDark => mode.value == ThemeMode.dark;

  Future<void> setMode(ThemeMode m) async {
    // The reactive GetMaterialApp in main.dart watches [mode]; just update it.
    mode.value = m;
    await _prefs.setString(StorageKeys.themeMode, m.name);
  }

  /// Convenience toggle between light and dark.
  Future<void> toggleDark(bool dark) =>
      setMode(dark ? ThemeMode.dark : ThemeMode.light);

  ThemeMode _parse(String? s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
