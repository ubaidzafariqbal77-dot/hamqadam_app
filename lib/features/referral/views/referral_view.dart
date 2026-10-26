import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/referral_controller.dart';
import '../../../repositories/referral_repository.dart';
import '../../../widgets/premium_app_bar.dart';

/// Referral programme — the same code, link, rewards and history the web
/// dashboard shows (`/member/referrals`).
class ReferralView extends StatefulWidget {
  const ReferralView({super.key});

  static Future<void> open() async {
    await Get.to<void>(() => const ReferralView());
  }

  @override
  State<ReferralView> createState() => _ReferralViewState();
}

class _ReferralViewState extends State<ReferralView> {
  final ReferralController c = Get.find<ReferralController>();

  @override
  void initState() {
    super.initState();
    c.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F8),
      appBar: const PremiumAppBar(title: 'Referral & Rewards'),
      body: RefreshIndicator(
        onRefresh: c.load,
        child: Obx(() {
          final ReferralSummary s = c.summary.value;
          if (c.loading.value && s.code.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              if (c.error.value != null) _Card(child: Text(c.error.value!)),
              _codeCard(s),
              const SizedBox(height: 12),
              _statsGrid(s),
              const SizedBox(height: 12),
              _rulesCard(s),
              const SizedBox(height: 12),
              _section('Referred members', c.members.isEmpty
                  ? <Widget>[const _Empty('No one has joined with your code yet.')]
                  : c.members.map(_memberTile).toList()),
              const SizedBox(height: 12),
              _section('Reward history', c.rewards.isEmpty
                  ? <Widget>[const _Empty('No rewards credited yet.')]
                  : c.rewards.map(_rewardTile).toList()),
              const SizedBox(height: 24),
            ],
          );
        }),
      ),
    );
  }

  Widget _codeCard(ReferralSummary s) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: <Color>[Color(0xFFB23A5E), Color(0xFFE87AA0)],
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Your referral code',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 6),
        Text(s.code.isEmpty ? '—' : s.code,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 2)),
        const SizedBox(height: 14),
        Row(children: <Widget>[
          Expanded(
            child: _pill(Icons.copy_rounded, 'Copy code', () => c.copy(s.code, 'Code')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _pill(Icons.link_rounded, 'Copy link', () => c.copy(s.url, 'Link')),
          ),
        ]),
      ],
    ),
  );

  Widget _pill(IconData i, String t, VoidCallback f) => InkWell(
    onTap: f,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        Icon(i, size: 16, color: const Color(0xFFB23A5E)),
        const SizedBox(width: 6),
        Text(t,
            style: const TextStyle(
                color: Color(0xFFB23A5E), fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    ),
  );

  Widget _statsGrid(ReferralSummary s) {
    final List<(String, String)> items = <(String, String)>[
      ('Total referrals', '${s.total}'),
      ('Rewarded', '${s.rewarded}'),
      ('Pending', '${s.pending}'),
      ('Coins earned', '${s.coinsEarned}'),
      ('Registration coins', '${s.registrationCoins}'),
      ('Package coins', '${s.packageCoins}'),
    ];
    return Column(children: <Widget>[
      for (int i = 0; i < items.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: <Widget>[
            Expanded(child: _stat(items[i].$1, items[i].$2)),
            const SizedBox(width: 10),
            Expanded(child: _stat(items[i + 1].$1, items[i + 1].$2)),
          ]),
        ),
      _Card(
        child: Row(children: <Widget>[
          const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFB23A5E)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Your coin balance')),
          Text('${s.remainingCoins}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
      ),
    ]);
  }

  Widget _stat(String l, String v) => _Card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(l, style: AppTextStyles.caption),
    ]),
  );

  Widget _rulesCard(ReferralSummary s) => _section('How rewards work', <Widget>[
    _rule('Registration reward', s.registrationRule),
    _rule('Package activation reward', s.packageRule),
    if (s.eligibility.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(s.eligibility, style: AppTextStyles.caption),
      ),
  ]);

  Widget _rule(String t, ReferralRule r) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: <Widget>[
      Icon(r.active ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
          size: 18, color: r.active ? AppColors.success : Colors.grey),
      const SizedBox(width: 8),
      Expanded(child: Text(t)),
      Text(r.active
          ? '${r.coins} coins${r.max > 0 ? ' · max ${r.max}' : ''}'
          : 'Inactive'),
    ]),
  );

  Widget _memberTile(ReferredMember m) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: const CircleAvatar(
      backgroundColor: Color(0xFFFFE4EC),
      child: Icon(Icons.person_rounded, color: Color(0xFFB23A5E)),
    ),
    title: Text(m.name.isEmpty ? 'Member #${m.id}' : m.name),
    subtitle: Text(<String>[
      if (m.joinedAt != null) 'Joined ${_date(m.joinedAt!)}',
      m.emailVerified ? 'Email verified' : 'Email pending',
    ].join(' · ')),
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        _badge(m.registrationRewarded ? 'Registration ✓' : 'Registration pending',
            m.registrationRewarded),
        const SizedBox(height: 3),
        _badge(m.packageRewarded ? 'Package ✓' : 'Package pending', m.packageRewarded),
      ],
    ),
  );

  Widget _badge(String t, bool ok) => Text(t,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ok ? AppColors.success : Colors.grey));

  Widget _rewardTile(ReferralReward r) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.monetization_on_rounded, color: Color(0xFFE0A100)),
    title: Text(r.label),
    subtitle: r.createdAt == null ? null : Text(_date(r.createdAt!)),
    trailing: Text('+${r.coins}',
        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success)),
  );

  String _date(DateTime d) {
    final DateTime l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  Widget _section(String title, List<Widget> children) => _Card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(title, style: AppTextStyles.bodyStrong),
      const SizedBox(height: 8),
      ...children,
    ]),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: const Color(0xFFF3F4F6)),
    ),
    child: child,
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(8), child: Text(text, style: AppTextStyles.caption));
}
