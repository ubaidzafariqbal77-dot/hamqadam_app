/// Annual-income and sibling option lists.
///
/// These lists were reported missing from the app, and they are missing because
/// the server does not supply them: `GET /profile/dropdown-reference-data`
/// returns 29 lists and none of them is an income or a sibling list.
///
/// The `annual_salary_ranges` table is no longer empty, though — see
/// [SalaryRangeOptions]. Registration now REQUIRES `annual_salary_range_id`,
/// and the ids it accepts (1–16) are the server's, so that list is not a free
/// product decision the way the bands below are.
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

/// Salary bands backing `annual_salary_range_id`.
///
/// `GET /auth/register/steps` lists step 10 as
/// `["annual_salary_range_id", "employment_status", …]` — `annual_income` is
/// gone — and `POST /auth/register/complete` answers a payload without it with
/// "The annual salary range id field is required." So this id, not the numeric
/// income, is what registration must send.
///
/// ## The ids belong to the server
///
/// `annual_salary_ranges` holds 16 rows: ids 1–16 pass `exists` validation and
/// 17 upwards are rejected. The authoritative list — ids WITH their labels —
/// comes from `GET /profile/dropdown-reference-data` under the
/// `annual_salary_ranges` key, and [LookupRepository] prefers the server copy
/// over everything here, so a served list silently replaces this one.
///
/// ## PROVISIONAL LABELS — verify before release
///
/// The reference payload bundled in `assets/lookups/dropdown_reference.json`
/// predates this backend change and carries no `annual_salary_ranges` key, and
/// the endpoint needs a bearer token, so the sixteen labels below could not be
/// read off the API. Their COUNT and their IDS are verified against the server;
/// their WORDING is not. Confirm them with
///
/// ```
/// curl -s -H "Authorization: Bearer <token>" -H "Accept: application/json" \
///   https://hamqadam.com/api/v1/profile/dropdown-reference-data \
///   | python3 -c "import sys,json;print(json.load(sys.stdin)['data'].get('annual_salary_ranges'))"
/// ```
///
/// and replace [bands] with what it prints. If that key is missing from the
/// response, the backend has to start serving it — an app cannot label a
/// foreign key it is never told the names of.
class SalaryRangeOptions {
  const SalaryRangeOptions._();

  /// Highest id the server accepts. Used only to drop a stale stored value that
  /// no longer points at a row.
  static const int maxId = 16;

  /// id → label. Ids are the server's; see the class note about the labels.
  static const List<LookupItem> bands = <LookupItem>[
    LookupItem(id: 1, name: 'Under PKR 1 Lac'),
    LookupItem(id: 2, name: 'PKR 1 – 2 Lac'),
    LookupItem(id: 3, name: 'PKR 2 – 3 Lac'),
    LookupItem(id: 4, name: 'PKR 3 – 4 Lac'),
    LookupItem(id: 5, name: 'PKR 4 – 6 Lac'),
    LookupItem(id: 6, name: 'PKR 6 – 8 Lac'),
    LookupItem(id: 7, name: 'PKR 8 – 10 Lac'),
    LookupItem(id: 8, name: 'PKR 10 – 15 Lac'),
    LookupItem(id: 9, name: 'PKR 15 – 20 Lac'),
    LookupItem(id: 10, name: 'PKR 20 – 25 Lac'),
    LookupItem(id: 11, name: 'PKR 25 – 35 Lac'),
    LookupItem(id: 12, name: 'PKR 35 – 50 Lac'),
    LookupItem(id: 13, name: 'PKR 50 – 75 Lac'),
    LookupItem(id: 14, name: 'PKR 75 Lac – 1 Crore'),
    LookupItem(id: 15, name: 'PKR 1 – 2 Crore'),
    LookupItem(id: 16, name: 'Above PKR 2 Crore'),
  ];

  static List<LookupItem> get options => bands;

  /// True for an id the server will accept. A value outside the range is
  /// treated as absent rather than posted and rejected.
  static bool isValid(int? id) => id != null && id >= 1 && id <= maxId;
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
