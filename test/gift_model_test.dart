import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/models/gift_model.dart';

void main() {
  group('Gift model tests', () {
    test('parses a gift row from GET /gifts', () {
      final GiftModel gift = GiftModel.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Roses Bouquet',
        'slug': 'roses_bouquet',
        'thumbnail': 'assets/gift_thumbnail/Gift1.png',
        'animated_asset': 'assets/animated_gifts/gift_1_roses_bouquet.json',
        'coins': 2,
        'category': 'general',
        'sort_order': 1,
        'is_active': true,
      });

      expect(gift.id, 1);
      expect(gift.name, 'Roses Bouquet');
      expect(gift.coins, 2);
      expect(gift.sortOrder, 1);
      expect(gift.isActive, true);
      expect(gift.thumbnail, 'assets/gift_thumbnail/Gift1.png');
      expect(gift.animatedAsset, 'assets/animated_gifts/gift_1_roses_bouquet.json');
    });

    test('parses a gift transaction with sender/receiver/direction', () {
      final GiftTransactionModel t = GiftTransactionModel.fromJson(<String, dynamic>{
        'id': 55,
        'gift': <String, dynamic>{
          'id': 3,
          'name': 'Chocolate Box',
          'slug': 'chocolate_box',
          'coins': 6,
        },
        'sender': <String, dynamic>{'id': 10, 'name': 'Muhammad'},
        'receiver': <String, dynamic>{'id': 20, 'name': 'Sana'},
        'coins': 6,
        'message': 'Best wishes',
        'status': 'sent',
        'direction': 'received',
        'created_at': '2026-09-25T10:25:00.000000Z',
      });

      expect(t.id, 55);
      expect(t.gift?.name, 'Chocolate Box');
      expect(t.senderName, 'Muhammad');
      expect(t.receiverName, 'Sana');
      expect(t.coins, 6);
      expect(t.direction, 'received');
      expect(t.message, 'Best wishes');
      expect(t.createdAt, isNotNull);
    });

    test('parses the send result (remaining coins from backend wallet)', () {
      final SendGiftResult result = SendGiftResult.fromJson(<String, dynamic>{
        'gift_transaction_id': 123,
        'gift': <String, dynamic>{'id': 1, 'name': 'Roses Bouquet', 'coins': 2},
        'remaining_coins': 98,
      });

      expect(result.giftTransactionId, 123);
      expect(result.remainingCoins, 98);
      expect(result.gift?.coins, 2);
    });

    test('missing fields fall back safely (no crashes on partial data)', () {
      final GiftModel gift = GiftModel.fromJson(<String, dynamic>{});
      expect(gift.id, 0);
      expect(gift.name, '');
      expect(gift.coins, 0);
      expect(gift.isActive, false);
    });
  });
}
