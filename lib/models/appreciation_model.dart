/// Like / Super Like data from `/appreciations/*`.
class AppreciationStatus {
  const AppreciationStatus({
    this.liked = false,
    this.superLiked = false,
    this.likedMe = false,
    this.superLikedMe = false,
    this.superLikeCost = 10,
    this.coinBalance = 0,
  });

  final bool liked;
  final bool superLiked;
  final bool likedMe;
  final bool superLikedMe;
  final int superLikeCost;
  final int coinBalance;

  factory AppreciationStatus.fromJson(Map<String, dynamic> json) => AppreciationStatus(
        liked: json['liked'] == true,
        superLiked: json['super_liked'] == true,
        likedMe: json['liked_me'] == true,
        superLikedMe: json['super_liked_me'] == true,
        superLikeCost: _int(json['super_like_cost'], 10),
        coinBalance: _int(json['coin_balance'], 0),
      );
}

class SuperLikeResult {
  const SuperLikeResult({required this.created, required this.balance, required this.cost});

  /// False when this pair was already Super Liked — the server did not charge again.
  final bool created;
  final int balance;
  final int cost;

  factory SuperLikeResult.fromJson(Map<String, dynamic> json) => SuperLikeResult(
        created: json['created'] == true,
        balance: _int(json['balance'], 0),
        cost: _int(json['cost'], 0),
      );
}

enum AppreciationType { like, superLike }

extension AppreciationTypeApi on AppreciationType {
  String get apiValue => this == AppreciationType.like ? 'like' : 'super_like';
}

/// One row of Profile Activity — the other member is the sender on the
/// Received tab and the recipient on the Sent tab.
class AppreciationActivity {
  const AppreciationActivity({
    required this.id,
    required this.type,
    required this.status,
    this.userId,
    this.userName,
    this.userPhoto,
    this.createdAt,
  });

  final int id;
  final AppreciationType type;
  final String status;
  final int? userId;
  final String? userName;
  final String? userPhoto;
  final DateTime? createdAt;

  factory AppreciationActivity.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> user =
        json['user'] is Map ? Map<String, dynamic>.from(json['user'] as Map) : <String, dynamic>{};
    return AppreciationActivity(
      id: _int(json['id'], 0),
      type: json['type'] == 'super_like' ? AppreciationType.superLike : AppreciationType.like,
      status: (json['status'] ?? 'sent').toString(),
      userId: user['id'] == null ? null : _int(user['id'], 0),
      userName: user['name']?.toString(),
      userPhoto: user['photo']?.toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString())?.toLocal(),
    );
  }
}

class AppreciationActivityPage {
  const AppreciationActivityPage({required this.items, this.currentPage = 1, this.lastPage = 1});

  final List<AppreciationActivity> items;
  final int currentPage;
  final int lastPage;
}

int _int(dynamic v, int fallback) => v is int ? v : int.tryParse('${v ?? ''}') ?? fallback;
