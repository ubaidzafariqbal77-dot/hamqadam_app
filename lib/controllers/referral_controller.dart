import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../repositories/referral_repository.dart';
import '../widgets/app_snackbar.dart';

/// Drives the Referral screen: summary, referred members and reward ledger.
class ReferralController extends GetxController {
  ReferralController(this._repo);

  final ReferralRepository _repo;

  final Rx<ReferralSummary> summary = const ReferralSummary().obs;
  final RxList<ReferredMember> members = <ReferredMember>[].obs;
  final RxList<ReferralReward> rewards = <ReferralReward>[].obs;
  final RxBool loading = false.obs;
  final RxnString error = RxnString();

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      summary.value = await _repo.fetchSummary();
      final List<dynamic> rest = await Future.wait<dynamic>(<Future<dynamic>>[
        _repo.fetchMembers().catchError((_) => <ReferredMember>[]),
        _repo.fetchRewards().catchError((_) => <ReferralReward>[]),
      ]);
      members.assignAll(rest[0] as List<ReferredMember>);
      rewards.assignAll(rest[1] as List<ReferralReward>);
    } catch (e) {
      error.value = 'Could not load referral details. Pull to retry.';
    } finally {
      loading.value = false;
    }
  }

  Future<void> copy(String text, String what) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.success('$what copied');
  }
}
