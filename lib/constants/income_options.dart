/// Annual-income and sibling option lists.
///
/// These three lists were reported missing from the app, and they are missing
/// because the server does not supply them:
/// `GET /profile/dropdown-reference-data` returns 29 lists and none of them is
/// an income or a sibling list. The `annual_salary_ranges` table that would
/// back one exists in the schema but has no rows, so `annual_salary_range_id`
/// has nothing to point at.
///
/// So the options live here, in the same shape every other dropdown uses. If
/// the backend later adds `annual_income` / `siblings` keys to the reference
/// payload, [LookupRepository] prefers the server copy automatically and this
/// file stops being consulted — no UI change needed.
///
/// ## What gets sent
///
/// * `annual_income` — `members.annual_income` is `decimal(12,2)`, so a NUMBER
///   goes to the server, not the label. Each band submits its LOWER BOUND, and
///   [IncomeBand.forValue] maps a stored number back to its band for display.
/// * `income_min` / `income_max` (partner preferences) — numeric, taken from
///   the chosen band's bounds.
/// * `siblings_brothers` / `siblings_sisters` — `unsignedTinyInteger`,
///   validated `0..50`, so plain integers.
///
/// ## Note on the bands themselves
///
/// The amounts below are annual PKR and are a product decision, not something
/// read off the API. They are all in this one file so they can be retuned
/// without touching any screen.
library;

import '../models/lookup_item_model.dart';

/// One annual-income band.
class IncomeBand {
  const IncomeBand({required this.min, required this.label, this.max});

  /// Lower bound, inclusive. This is the value submitted for `annual_income`.
  final int min;

  /// Upper bound, inclusive. Null on the open-ended top band.
  final int? max;

  final String label;

  bool contains(num value) => value >= min && (max == null || value <= max!);

  /// Dropdown row. `id` is the lower bound, so [LookupItem.apiValue] is already
  /// the number the API wants.
  LookupItem get item => LookupItem(id: min, name: label);

  /// Annual income in PKR.
  static const List<IncomeBand> bands = <IncomeBand>[
    IncomeBand(min: 0, max: 299999, label: 'Under PKR 3 Lac'),
    IncomeBand(min: 300000, max: 599999, label: 'PKR 3 – 6 Lac'),
    IncomeBand(min: 600000, max: 999999, label: 'PKR 6 – 10 Lac'),
    IncomeBand(min: 1000000, max: 1499999, label: 'PKR 10 – 15 Lac'),
    IncomeBand(min: 1500000, max: 2499999, label: 'PKR 15 – 25 Lac'),
    IncomeBand(min: 2500000, max: 3999999, label: 'PKR 25 – 40 Lac'),
    IncomeBand(min: 4000000, max: 5999999, label: 'PKR 40 – 60 Lac'),
    IncomeBand(min: 6000000, max: 9999999, label: 'PKR 60 Lac – 1 Crore'),
    IncomeBand(min: 10000000, label: 'Above PKR 1 Crore'),
  ];

  /// Dropdown rows for the member's own income (registration step 10, and the
  /// Career & Income section of profile edit).
  static List<LookupItem> get options =>
      bands.map((IncomeBand b) => b.item).toList(growable: false);

  /// The band a stored amount falls into, for rendering a saved value.
  static IncomeBand? forValue(num? value) {
    if (value == null) return null;
    for (final IncomeBand b in bands) {
      if (b.contains(value)) return b;
    }
    return null;
  }

  /// Label for a stored amount, e.g. `1200000` → `PKR 10 – 15 Lac`.
  static String? labelFor(num? value) => forValue(value)?.label;
}

/// Sibling counts.
///
/// `siblings_brothers` / `siblings_sisters` accept 0–50, but a picker past ten
/// is noise; the top row covers the rest and submits 11.
class SiblingOptions {
  const SiblingOptions._();

  static const int maxListed = 10;

  static List<LookupItem> get options => <LookupItem>[
    const LookupItem(id: 0, name: 'None'),
    for (int i = 1; i <= maxListed; i++)
      LookupItem(id: i, name: '$i'),
    const LookupItem(id: maxListed + 1, name: 'More than $maxListed'),
  ];

  /// Label for a stored count.
  static String labelFor(int? count) {
    if (count == null) return '';
    if (count <= 0) return 'None';
    if (count > maxListed) return 'More than $maxListed';
    return '$count';
  }
}
