/// A single selectable dropdown option.
///
/// `GET /profile/dropdown-reference-data` returns two shapes in the same body:
///
/// * database-backed lists — `{"id": 166, "name": "Pakistan"}`, dependent lists
///   carrying their parent as a typed key (`country_id`, `state_id`,
///   `caste_id`, `education_level_id`, `degree_id`, `profession_category_id`,
///   `religion_id`, `sect_main_id`, `school_of_thought_id`);
/// * hardcoded lists — `{"id": "immediate", "name": "Immediate"}` and
///   `{"id": "Reading", "name": "Reading"}`, whose id is a string.
///
/// Both are represented here: [id] is the numeric id (0 for string options) and
/// [code] holds the string id. [apiValue] is what must be sent to the backend.
class LookupItem {
  const LookupItem({required this.id, required this.name, this.parentId, this.code});

  /// A hardcoded option whose API value is a string (`immediate`, `yes`, …).
  const LookupItem.option(String value, String label)
    : id = 0,
      name = label,
      parentId = null,
      code = value;

  final int id;
  final String name;
  final int? parentId;

  /// String id for hardcoded/option lists, null for database-backed rows.
  final String? code;

  /// The value the API expects for this option.
  dynamic get apiValue => code ?? id;

  bool get isOption => code != null;

  /// Keys that may carry the parent id of a dependent list, in priority order.
  static const List<String> parentKeys = <String>[
    'parent_id',
    'country_id',
    'state_id',
    'city_id',
    'caste_id',
    'education_level_id',
    'degree_id',
    'profession_category_id',
    'religion_id',
    'sect_main_id',
    'school_of_thought_id',
  ];

  factory LookupItem.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'] ?? json['value'] ?? json['key'];
    final int? numericId = _asIntOrNull(rawId);
    return LookupItem(
      id: numericId ?? 0,
      name: (json['name'] ?? json['title'] ?? json['label'] ?? rawId ?? '').toString(),
      parentId: _parentOf(json),
      code: numericId == null && rawId != null ? rawId.toString() : null,
    );
  }

  static int? _parentOf(Map<String, dynamic> json) {
    for (final String key in parentKeys) {
      if (json.containsKey(key)) {
        final int? v = _asIntOrNull(json[key]);
        if (v != null) return v;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is LookupItem && other.id == id && other.code == code;

  @override
  int get hashCode => Object.hash(id, code);

  static int? _asIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse('$v');
  }
}
