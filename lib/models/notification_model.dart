class NotificationModel {
  final int id;
  final String type;
  final String title;
  final String message;
  final String? deepLink;
  final int? notifyBy;
  final int? infoId;
  final Map<String, dynamic>? payload;
  final DateTime? readAt;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.deepLink,
    this.notifyBy,
    this.infoId,
    this.payload,
    this.readAt,
    this.createdAt,
  });

  bool get isRead => readAt != null;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      deepLink: json['deep_link'],
      notifyBy: json['notify_by'],
      infoId: json['info_id'],
      payload: json['payload'] as Map<String, dynamic>?,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
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
