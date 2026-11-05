class NotificationModel {
  final int id;
  final String type;
  final String typeFallback;
  final String title;
  final String message;
  final String? deepLink;
  final int? notifyBy;
  final int? infoId;
  final Map<String, dynamic>? payload;
  final String? category;
  final String? deliveryStatus;
  final DateTime? readAt;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.typeFallback,
    required this.title,
    required this.message,
    this.deepLink,
    this.notifyBy,
    this.infoId,
    this.payload,
    this.category,
    this.deliveryStatus,
    this.readAt,
    this.createdAt,
  });

  bool get isRead => readAt != null;

  /// Chat notifications ("Ubaid DEV: message preview") live in the inbox —
  /// the list keeps activity notifications only.
  bool get isChatMessage {
    final String t = type.toLowerCase();
    return t.contains('message') || t.contains('chat');
  }

  /// Engagement helper: which app screen this notification is about.
  ///
  /// The backend writes a stable event key/route (`notification_events.php`),
  /// so the UI can route a tap even when it has never seen this notification
  /// type before.
  String get route {
    if (deepLink != null && deepLink!.isNotEmpty) return deepLink!;
    final dynamic p = payload;
    if (p is Map<String, dynamic>) {
      final String? route = p['route']?.toString();
      if (route != null && route.isNotEmpty) return route;
      final String? deepLinkFromPayload = p['deep_link']?.toString();
      if (deepLinkFromPayload != null && deepLinkFromPayload.isNotEmpty) {
        return deepLinkFromPayload;
      }
    }
    return '/';
  }

  NotificationModel copyWith({
    int? id,
    String? type,
    String? typeFallback,
    String? title,
    String? message,
    String? deepLink,
    int? notifyBy,
    int? infoId,
    Map<String, dynamic>? payload,
    String? category,
    String? deliveryStatus,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      typeFallback: typeFallback ?? this.typeFallback,
      title: title ?? this.title,
      message: message ?? this.message,
      deepLink: deepLink ?? this.deepLink,
      notifyBy: notifyBy ?? this.notifyBy,
      infoId: infoId ?? this.infoId,
      payload: payload ?? this.payload,
      category: category ?? this.category,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final String rawType = json['type']?.toString() ?? '';
    final String resolvedType = rawType.isNotEmpty ? rawType : 'notification';

    // The backend resource resolves `type` from `data.type` when present,
    // falling back to `class_basename($this->type)`. Keep both so the UI can
    // route on the product key while still rendering a sensible label.
    final String typeFallback =
        (json['data']?['type'] ?? json['type'] ?? json['event_key'] ?? 'notification').toString();

    final dynamic data = json['data'];
    final Map<String, dynamic> dataMap =
        data is Map<String, dynamic> ? data : <String, dynamic>{};

    final String rowTitle = (dataMap['title'] ?? json['title'] ?? '').toString();
    final String rowMessage = (dataMap['message'] ?? json['message'] ?? '').toString();

    // Build the canonical payload from the highest-priority source the server
    // actually sent: `data.payload` for the Laravel Resource shape, `data` for
    // the in-app rows, and the outer `payload` for the legacy flat row.
    final dynamic dataPayload = json['data']?['payload'];
    final Map<String, dynamic>? canonicalPayload;
    final Map<String, dynamic> fullPayload;
    if (dataMap.isNotEmpty) {
      if (dataPayload is Map<String, dynamic>) {
        // The resource wraps a small custom payload inside `data`; merge so
        // route/deep_link/notify_by from `data` survive alongside the
        // event-specific keys in `data.payload`.
        canonicalPayload = <String, dynamic>{
          ...dataMap,
          ...dataPayload,
        };
      } else {
        canonicalPayload = Map<String, dynamic>.from(dataMap);
      }
    } else if (json['payload'] is Map<String, dynamic>) {
      canonicalPayload = Map<String, dynamic>.from(json['payload'] as Map<String, dynamic>);
    } else if (dataPayload is Map<String, dynamic>) {
      canonicalPayload = Map<String, dynamic>.from(dataPayload);
    } else {
      canonicalPayload = null;
    }
    fullPayload = canonicalPayload ?? <String, dynamic>{};

    final String? deepLinkRaw = fullPayload['deep_link']?.toString() ??
        fullPayload['route']?.toString() ??
        dataMap['deep_link']?.toString() ??
        dataMap['route']?.toString() ??
        json['data']?['deep_link']?.toString() ??
        json['data']?['route']?.toString() ??
        json['deep_link']?.toString() ??
        json['route']?.toString();
    final String? deepLink = deepLinkRaw?.isEmpty == true ? null : deepLinkRaw;

    final dynamic categoryRaw = fullPayload['category'] ?? json['category'];
    final String? category = (categoryRaw is String && categoryRaw.isNotEmpty) ? categoryRaw : null;

    final dynamic deliveryRaw = fullPayload['delivery_status'] ?? json['delivery_status'];
    final String? deliveryStatus = (deliveryRaw is String && deliveryRaw.isNotEmpty) ? deliveryRaw : null;

    final DateTime? readAtFromJson =
        json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null;
    final DateTime? createdAtFromJson =
        json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null;

    return NotificationModel(
      id: json['id'] ?? 0,
      type: resolvedType,
      typeFallback: typeFallback,
      title: rowTitle,
      message: rowMessage,
      deepLink: deepLink,
      notifyBy: _intOrNull(fullPayload['notify_by'] ?? json['notify_by']),
      infoId: _intOrNull(fullPayload['info_id'] ?? json['info_id']),
      payload: canonicalPayload,
      category: category,
      deliveryStatus: deliveryStatus,
      readAt: readAtFromJson,
      createdAt: createdAtFromJson,
    );
  }

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

class NotificationPage {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final int currentPage;
  final int lastPage;

  NotificationPage({
    required this.notifications,
    required this.unreadCount,
    required this.currentPage,
    required this.lastPage,
  });

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final List<dynamic> data = json['data'] ?? [];
    final meta = json['meta'] ?? {};
    return NotificationPage(
      notifications: data.map((e) => NotificationModel.fromJson(e)).toList(),
      unreadCount: meta['unread_count'] ?? 0,
      currentPage: meta['current_page'] ?? 1,
      lastPage: meta['last_page'] ?? 1,
    );
  }
}
