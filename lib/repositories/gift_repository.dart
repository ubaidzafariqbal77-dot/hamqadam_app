import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/gift_model.dart';

/// Gift feature API calls. Coins/balance are never computed here — the
/// backend deducts from the existing package wallet and returns the real
/// remaining balance with every send.
class GiftRepository {
  GiftRepository(this._client);

  final ApiClient _client;

  /// `GET /gifts` — active catalog, sorted by sort_order ASC.
  Future<List<GiftModel>> fetchGifts() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.gifts);
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().map(GiftModel.fromJson).toList();
  }

  /// `GET /gifts/{id}` — one gift.
  Future<GiftModel> fetchGift(int giftId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.giftDetail(giftId));
    return GiftModel.fromJson(res.dataMap);
  }

  /// `POST /gifts/send` — backend loads the price from the DB and deducts it
  /// from the existing coin balance inside a locked transaction.
  Future<SendGiftResult> sendGift({
    required int receiverId,
    required int giftId,
    String? message,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.giftsSend,
      body: <String, dynamic>{
        'receiver_id': receiverId,
        'gift_id': giftId,
        if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
      },
    );
    if (!res.success) {
      throw Exception(res.message.isNotEmpty ? res.message : 'Gift could not be sent.');
    }
    return SendGiftResult.fromJson(res.dataMap);
  }

  /// `GET /gifts/received`.
  Future<List<GiftTransactionModel>> fetchReceived({int page = 1}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.giftsReceived,
      query: <String, dynamic>{'page': page},
    );
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().map(GiftTransactionModel.fromJson).toList();
  }

  /// `GET /gifts/sent`.
  Future<List<GiftTransactionModel>> fetchSent({int page = 1}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.giftsSent,
      query: <String, dynamic>{'page': page},
    );
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().map(GiftTransactionModel.fromJson).toList();
  }

  /// `GET /gifts/transactions/{id}` — one gift (deep-link target).
  Future<GiftTransactionModel> fetchTransaction(int transactionId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.giftTransaction(transactionId));
    return GiftTransactionModel.fromJson(res.dataMap);
  }
}
