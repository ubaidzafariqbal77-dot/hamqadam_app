/// Gift catalog row from `GET /gifts`. The backend is the single source of
/// truth for names, prices and asset paths — nothing here is hardcoded.
class GiftModel {
  final int id;
  final String name;
  final String slug;
  final String thumbnail;
  final String animatedAsset;
  final int coins;
  final String category;
  final int sortOrder;
  final bool isActive;

  const GiftModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.thumbnail,
    required this.animatedAsset,
    required this.coins,
    required this.category,
    required this.sortOrder,
    required this.isActive,
  });

  factory GiftModel.fromJson(Map<String, dynamic> json) {
    return GiftModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      thumbnail: (json['thumbnail'] ?? '').toString(),
      animatedAsset: (json['animated_asset'] ?? '').toString(),
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      category: (json['category'] ?? 'general').toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] == true || json['is_active'] == 1,
    );
  }
}

/// One sent/received gift from `GET /gifts/received|sent` and
/// `GET /gifts/transactions/{id}`.
class GiftTransactionModel {
  final int id;
  final GiftModel? gift;
  final int? senderId;
  final String senderName;
  final int? receiverId;
  final String receiverName;
  final int coins;
  final String? message;
  final String status;
  final String direction; // 'sent' | 'received'
  final DateTime? createdAt;

  const GiftTransactionModel({
    required this.id,
    this.gift,
    this.senderId,
    required this.senderName,
    this.receiverId,
    required this.receiverName,
    required this.coins,
    this.message,
    required this.status,
    required this.direction,
    this.createdAt,
  });

  factory GiftTransactionModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> sender =
        (json['sender'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> receiver =
        (json['receiver'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return GiftTransactionModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      gift: json['gift'] is Map<String, dynamic>
          ? GiftModel.fromJson(json['gift'] as Map<String, dynamic>)
          : null,
      senderId: (sender['id'] as num?)?.toInt(),
      senderName: (sender['name'] ?? 'Member').toString(),
      receiverId: (receiver['id'] as num?)?.toInt(),
      receiverName: (receiver['name'] ?? 'Member').toString(),
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      message: json['message']?.toString(),
      status: (json['status'] ?? 'sent').toString(),
      direction: (json['direction'] ?? 'received').toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

/// Server answer to `POST /gifts/send`:
/// `{gift_transaction_id, gift, remaining_coins}`.
class SendGiftResult {
  final int giftTransactionId;
  final GiftModel? gift;
  final int remainingCoins;

  const SendGiftResult({
    required this.giftTransactionId,
    this.gift,
    required this.remainingCoins,
  });

  factory SendGiftResult.fromJson(Map<String, dynamic> json) {
    return SendGiftResult(
      giftTransactionId: (json['gift_transaction_id'] as num?)?.toInt() ?? 0,
      gift: json['gift'] is Map<String, dynamic>
          ? GiftModel.fromJson(json['gift'] as Map<String, dynamic>)
          : null,
      remainingCoins: (json['remaining_coins'] as num?)?.toInt() ?? 0,
    );
  }
}
