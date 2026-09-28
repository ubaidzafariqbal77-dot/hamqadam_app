import '../core/api/api_client.dart';
import '../core/api/api_response.dart';
import '../constants/api_endpoints.dart';

/// The 25-coin welcome bonus: state + claim, for the profile's Redeem section.
class RewardsRepository {
  RewardsRepository(this._client);

  final ApiClient _client;

  /// `GET /rewards/welcome`
  Future<WelcomeBonusState> fetchStatus() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.rewardsWelcome);
    return WelcomeBonusState.fromJson(res.dataMap);
  }

  /// `POST /rewards/welcome/claim`
  Future<WelcomeBonusState> claim() async {
    final ApiEnvelope res = await _client.post(ApiEndpoints.rewardsWelcomeClaim);
    return WelcomeBonusState.fromJson(res.dataMap);
  }
}

/// Server state for the welcome bonus (all booleans pre-computed server-side).
class WelcomeBonusState {
  const WelcomeBonusState({
    this.coins = 25,
    this.eligible = false,
    this.claimed = false,
    this.claimable = false,
    this.claimedAt,
    this.balance = 0,
    this.justClaimed = false,
  });

  final int coins;
  final bool eligible; // fully verified
  final bool claimed;
  final bool claimable; // verified AND not yet claimed → button enabled
  final DateTime? claimedAt;
  final int balance;
  final bool justClaimed; // set by the claim response wrapper

  factory WelcomeBonusState.fromJson(Map<String, dynamic> json) {
    return WelcomeBonusState(
      coins: _asInt(json['coins']) ?? 25,
      eligible: json['eligible'] == true || json['eligible'] == 1,
      claimed: json['claimed'] == true || json['claimed'] == 1,
      claimable: json['claimable'] == true || json['claimable'] == 1,
      claimedAt: json['claimed_at'] != null
          ? DateTime.tryParse('${json['claimed_at']}')
          : null,
      balance: _asInt(json['balance']) ?? 0,
    );
  }

  static int? _asInt(dynamic v) => v is int ? v : int.tryParse('$v');
}
