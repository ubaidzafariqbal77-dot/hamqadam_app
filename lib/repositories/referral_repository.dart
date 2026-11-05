import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';

/// Referral programme: code/link, referred members and the coin ledger.
/// Backed by `/api/v1/bridge/referrals/*` — the same service the web
/// dashboard uses, so rewards always match.
class ReferralRepository {
  ReferralRepository(this._client);

  final ApiClient _client;

  /// `GET /bridge/referrals/summary`
  Future<ReferralSummary> fetchSummary() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.referralSummary);
    return ReferralSummary.fromJson(res.dataMap);
  }

  /// `GET /bridge/referrals/members`
  Future<List<ReferredMember>> fetchMembers({int page = 1}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.referralMembers,
      query: <String, dynamic>{'page': page},
    );
    final dynamic list = res.dataMap['referrals'];
    return (list is List ? list : <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ReferredMember.fromJson)
        .toList(growable: false);
  }

  /// `GET /bridge/referrals/rewards`
  Future<List<ReferralReward>> fetchRewards({int page = 1}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.referralRewards,
      query: <String, dynamic>{'page': page},
    );
    final dynamic list = res.dataMap['transactions'];
    return (list is List ? list : <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ReferralReward.fromJson)
        .toList(growable: false);
  }
}

int _int(dynamic v) => v is int ? v : (int.tryParse('$v') ?? 0);
bool _bool(dynamic v) => v == true || v == 1 || v == '1';

class ReferralRule {
  const ReferralRule({this.active = false, this.coins = 0, this.max = 0});
  final bool active;
  final int coins;
  final int max;

  factory ReferralRule.fromJson(dynamic j, String coinKey) {
    final Map<String, dynamic> m = j is Map<String, dynamic> ? j : <String, dynamic>{};
    return ReferralRule(
      active: _bool(m['active']),
      coins: _int(m[coinKey]),
      max: _int(m['max_rewards_per_member']),
    );
  }
}

class ReferralSummary {
  const ReferralSummary({
    this.code = '',
    this.url = '',
    this.total = 0,
    this.rewarded = 0,
    this.pending = 0,
    this.registrationCoins = 0,
    this.packageCoins = 0,
    this.packageRewards = 0,
    this.coinsEarned = 0,
    this.remainingCoins = 0,
    this.registrationRule = const ReferralRule(),
    this.packageRule = const ReferralRule(),
    this.eligibility = '',
  });

  final String code;
  final String url;
  final int total;
  final int rewarded;
  final int pending;
  final int registrationCoins;
  final int packageCoins;
  final int packageRewards;
  final int coinsEarned;
  final int remainingCoins;
  final ReferralRule registrationRule;
  final ReferralRule packageRule;
  final String eligibility;

  factory ReferralSummary.fromJson(Map<String, dynamic> j) => ReferralSummary(
    code: '${j['referral_code'] ?? ''}',
    url: '${j['referral_url'] ?? ''}',
    total: _int(j['total_referrals']),
    rewarded: _int(j['rewarded_referrals']),
    pending: _int(j['pending_referrals']),
    registrationCoins: _int(j['registration_coins_earned']),
    packageCoins: _int(j['package_coins_earned']),
    packageRewards: _int(j['package_activation_rewards']),
    coinsEarned: _int(j['coins_earned']),
    remainingCoins: _int(j['remaining_coins']),
    registrationRule: ReferralRule.fromJson(j['reward_rule'], 'coins_per_referral'),
    packageRule: ReferralRule.fromJson(j['package_reward_rule'], 'coins_per_activation'),
    eligibility: '${j['eligibility'] ?? ''}',
  );
}

class ReferredMember {
  const ReferredMember({
    required this.id,
    required this.name,
    this.joinedAt,
    this.emailVerified = false,
    this.registrationRewarded = false,
    this.packageRewarded = false,
  });

  final int id;
  final String name;
  final DateTime? joinedAt;
  final bool emailVerified;
  final bool registrationRewarded;
  final bool packageRewarded;

  factory ReferredMember.fromJson(Map<String, dynamic> j) => ReferredMember(
    id: _int(j['id']),
    name: '${j['name'] ?? ''}'.trim(),
    joinedAt: DateTime.tryParse('${j['joined_at']}'),
    emailVerified: _bool(j['email_verified']),
    registrationRewarded: _bool(j['registration_reward_credited'] ?? j['reward_credited']),
    packageRewarded: _bool(j['package_activation_reward_credited']),
  );
}

class ReferralReward {
  const ReferralReward({
    required this.id,
    required this.coins,
    required this.type,
    this.createdAt,
  });

  final int id;
  final int coins;
  final String type; // registration | paid_package_activation
  final DateTime? createdAt;

  String get label =>
      type == 'paid_package_activation' ? 'Package activation reward' : 'Registration reward';

  factory ReferralReward.fromJson(Map<String, dynamic> j) => ReferralReward(
    id: _int(j['id']),
    coins: _int(j['coins']),
    type: '${j['reward_type'] ?? 'registration'}',
    createdAt: DateTime.tryParse('${j['created_at']}'),
  );
}
