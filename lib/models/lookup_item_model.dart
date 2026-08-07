/// A single selectable lookup option (`{id, name, parent_id}`), used for both
/// network and bundled lookup data.
class LookupItem {
  const LookupItem({required this.id, required this.name, this.parentId});

  final int id;
  final String name;
  final int? parentId;

  factory LookupItem.fromJson(Map<String, dynamic> json) {
    return LookupItem(
      id: _asInt(json['id']),
      name: (json['name'] ?? json['title'] ?? json['label'] ?? '').toString(),
      parentId: json.containsKey('parent_id') ? _asIntOrNull(json['parent_id']) : null,
    );
  }

  @override
  bool operator ==(Object other) => other is LookupItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  static int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
  static int? _asIntOrNull(dynamic v) => v == null ? null : (v is int ? v : int.tryParse('$v'));
}
