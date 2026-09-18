/// English → Urdu translations for the registration flow.
///
/// Urdu has been removed from the product: the map below is intentionally
/// EMPTY, so [AppUrdu.of] always returns null and every bilingual widget
/// ([BiText], FieldLabel, chips, StepScaffold) renders English-only.
/// The lookup is kept so the 20+ call-sites compile untouched — re-enabling
/// bilingual copy later only means filling this map again.
///
/// Keys must match the English source strings EXACTLY (after trimming).
class AppUrdu {
  const AppUrdu._();

  /// Returns the Urdu translation for [en], or null when none is registered.
  static String? of(String? en) {
    if (en == null) return null;
    final String key = en.trim();
    if (key.isEmpty) return null;
    return _map[key];
  }

  /// Intentionally empty — the app is English-only now.
  static const Map<String, String> _map = <String, String>{
    // No entries: Urdu is removed from the whole app.
  };
}
