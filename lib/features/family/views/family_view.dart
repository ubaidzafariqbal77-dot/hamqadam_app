import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/family_controller.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/premium_app_bar.dart';

/// Family & Wali mode: the member's guardians, wali-mode toggle, approval
/// requests (with approve/reject for guardians), managed profiles for
/// guardians, and the weekly digest summary.
class FamilyView extends StatefulWidget {
  const FamilyView({super.key});

  @override
  State<FamilyView> createState() => _FamilyViewState();
}

class _FamilyViewState extends State<FamilyView> {
  final FamilyController _controller = Get.find<FamilyController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadGuardians();
      _controller.loadApprovalRequests();
      _controller.loadManagedProfiles();
      _controller.loadDigest();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.roseCanvas,
      appBar: const PremiumAppBar(title: 'Family & Wali Mode'),
      body: RefreshIndicator(
        color: AppColors.regAccent,
        onRefresh: () async {
          await Future.wait(<Future<void>>[
            _controller.loadGuardians(),
            _controller.loadApprovalRequests(),
            _controller.loadManagedProfiles(),
            _controller.loadDigest(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 32),
          children: <Widget>[
            const _WaliModeCard(),
            _SectionCard(
              icon: Icons.approval_rounded,
              title: 'Approval Requests',
              child: const _ApprovalRequestsSection(),
            ),
            _SectionCard(
              icon: Icons.family_restroom_rounded,
              title: 'My Guardians',
              action: TextButton.icon(
                onPressed: _showInviteSheet,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Invite'),
              ),
              child: const _GuardiansSection(),
            ),
            _SectionCard(
              icon: Icons.supervisor_account_rounded,
              title: 'Profiles I Guard',
              child: const _ManagedProfilesSection(),
            ),
            _SectionCard(
              icon: Icons.insights_rounded,
              title: 'Weekly Digest',
              child: const _DigestSection(),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      builder: (BuildContext ctx) => _InviteGuardianSheet(controller: _controller),
    );
  }
}

// ---------------------------------------------------------------------------
// Wali mode toggle card
// ---------------------------------------------------------------------------

class _WaliModeCard extends StatelessWidget {
  const _WaliModeCard();

  @override
  Widget build(BuildContext context) {
    final FamilyController controller = Get.find<FamilyController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[AppColors.regAccent.withValues(alpha: 0.10), AppColors.regAccent.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.regAccent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.regAccent, shape: BoxShape.circle),
            child: const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Wali / Family Involvement', style: AppTextStyles.bodyStrong.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  'Guardians see your activity and approve important steps.',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Obx(() => Switch.adaptive(
                value: controller.waliModeEnabled.value,
                activeColor: AppColors.regAccent,
                onChanged: controller.toggleWaliMode,
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped section card
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.action,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: AppColors.regAccent),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: AppTextStyles.bodyStrong.copyWith(fontSize: 13.5))),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Approval requests
// ---------------------------------------------------------------------------

class _ApprovalRequestsSection extends StatelessWidget {
  const _ApprovalRequestsSection();

  @override
  Widget build(BuildContext context) {
    final FamilyController controller = Get.find<FamilyController>();

    return Obx(() {
      if (controller.approvalRequests.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(
            'No approval requests yet. Ask a guardian to approve a step, or wait for one to arrive.',
            style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
          ),
        );
      }

      return Column(
        children: controller.approvalRequests.map((Map<String, dynamic> r) {
          final Map<String, dynamic> guardian = (r['guardian'] as Map<String, dynamic>?) ?? <String, dynamic>{};
          final Map<String, dynamic> profile = (r['profile'] as Map<String, dynamic>?) ?? <String, dynamic>{};
          final String status = (r['status'] ?? 'pending').toString();
          final String name = (guardian['name'] ?? profile['name'] ?? 'Member').toString();
          final String type = (r['request_type'] ?? '').toString().replaceAll('_', ' ');

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lightSurfaceAlt.withValues(alpha: 0.6),
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.regAccent.withValues(alpha: 0.12),
                  backgroundImage: (profile['photo'] ?? guardian['photo']) != null
                      ? NetworkImage((profile['photo'] ?? guardian['photo'])!.toString())
                      : null,
                  child: (profile['photo'] ?? guardian['photo']) == null
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.regAccent, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(name, style: AppTextStyles.bodyStrong.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        type.isEmpty ? 'Approval' : type,
                        style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: status),
                if (status == 'pending' && (r['guardian'] as Map<String, dynamic>?) != null) ...<Widget>[
                  const SizedBox(width: 6),
                  _DecisionButtons(request: r),
                ],
              ],
            ),
          );
        }).toList(),
      );
    });
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        status,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _DecisionButtons extends StatelessWidget {
  const _DecisionButtons({required this.request});

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final FamilyController controller = Get.find<FamilyController>();
    final int id = (request['id'] as num?)?.toInt() ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InkWell(
          onTap: () => controller.approveRequest(id),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: () => controller.rejectRequest(id),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Guardians
// ---------------------------------------------------------------------------

class _GuardiansSection extends StatelessWidget {
  const _GuardiansSection();

  @override
  Widget build(BuildContext context) {
    final FamilyController controller = Get.find<FamilyController>();

    return Obx(() {
      if (controller.guardians.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text(
            'No guardians added yet. Invite a family member to involve them in your journey.',
            style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
          ),
        );
      }

      return Column(
        children: controller.guardians.map((Map<String, dynamic> g) {
          final Map<String, dynamic> guardian = (g['guardian'] as Map<String, dynamic>?) ?? <String, dynamic>{};
          final String name = (guardian['name'] ?? 'Guardian').toString();
          final String status = (g['status'] ?? 'pending').toString();
          final String relationship = (g['relationship'] ?? '').toString();
          final int id = (g['id'] as num?)?.toInt() ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lightSurfaceAlt.withValues(alpha: 0.6),
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.regAccent.withValues(alpha: 0.12),
                  backgroundImage: guardian['photo'] != null ? NetworkImage(guardian['photo'].toString()) : null,
                  child: guardian['photo'] == null
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.regAccent, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(name, style: AppTextStyles.bodyStrong.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (relationship.isNotEmpty)
                        Text(relationship, style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor)),
                    ],
                  ),
                ),
                if (status == 'pending')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const _StatusChip(status: 'pending'),
                      const SizedBox(width: 6),
                      if ((g['guardian'] as Map<String, dynamic>?) != null)
                        _DecisionButtons(request: g),
                    ],
                  )
                else ...<Widget>[
                  _StatusChip(status: status),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => controller.revokeGuardian(id),
                    borderRadius: BorderRadius.circular(999),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.error),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Managed profiles (guardian view)
// ---------------------------------------------------------------------------

class _ManagedProfilesSection extends StatelessWidget {
  const _ManagedProfilesSection();

  @override
  Widget build(BuildContext context) {
    final FamilyController controller = Get.find<FamilyController>();

    return Obx(() {
      if (controller.managedProfiles.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text(
            'You are not guarding any profiles yet. Once a member approves you as a guardian, their journey appears here.',
            style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
          ),
        );
      }

      return Column(
        children: controller.managedProfiles.map((Map<String, dynamic> p) {
          final Map<String, dynamic> profile = (p['profile'] as Map<String, dynamic>?) ?? p;
          final String name = (profile['name'] ?? 'Member').toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lightSurfaceAlt.withValues(alpha: 0.6),
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.regAccent.withValues(alpha: 0.12),
                  backgroundImage: profile['photo'] != null ? NetworkImage(profile['photo'].toString()) : null,
                  child: profile['photo'] == null
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.regAccent, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name, style: AppTextStyles.bodyStrong.copyWith(fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.lightTextHint),
              ],
            ),
          );
        }).toList(),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Digest
// ---------------------------------------------------------------------------

class _DigestSection extends StatelessWidget {
  const _DigestSection();

  @override
  Widget build(BuildContext context) {
    final FamilyController controller = Get.find<FamilyController>();

    return Obx(() {
      final Map<String, dynamic> d = controller.digest;
      final int managed = (d['managed_profiles'] as num?)?.toInt() ?? 0;
      final int proposals = (d['new_proposals_this_week'] as num?)?.toInt() ?? 0;
      final int pending = (d['pending_family_approvals'] as num?)?.toInt() ?? 0;

      return Row(
        children: <Widget>[
          _DigestStat(icon: Icons.people_outline_rounded, label: 'Profiles', value: managed),
          _DigestStat(icon: Icons.mail_outline_rounded, label: 'Proposals', value: proposals),
          _DigestStat(icon: Icons.hourglass_top_rounded, label: 'Pending', value: pending),
        ],
      );
    });
  }
}

class _DigestStat extends StatelessWidget {
  const _DigestStat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.regAccent.withValues(alpha: 0.06),
          borderRadius: AppRadius.mdAll,
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 20, color: AppColors.regAccent),
            const SizedBox(height: 6),
            Text('$value', style: AppTextStyles.bodyStrong.copyWith(fontSize: 18, color: AppColors.regAccent)),
            Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invite guardian sheet
// ---------------------------------------------------------------------------

class _InviteGuardianSheet extends StatefulWidget {
  const _InviteGuardianSheet({required this.controller});

  final FamilyController controller;

  @override
  State<_InviteGuardianSheet> createState() => _InviteGuardianSheetState();
}

class _InviteGuardianSheetState extends State<_InviteGuardianSheet> {
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _relCtrl = TextEditingController();
  String _role = 'guardian';

  static const List<String> _roles = <String>['guardian', 'wali'];

  @override
  void dispose() {
    _idCtrl.dispose();
    _relCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final int? userId = int.tryParse(_idCtrl.text.trim());
    if (userId == null || userId <= 0) {
      AppSnackbar.info('Enter the member ID of your guardian.');
      return;
    }
    final bool ok = await widget.controller.inviteGuardian(
      guardianUserId: userId,
      relationship: _relCtrl.text.trim().isEmpty ? 'Family' : _relCtrl.text.trim(),
      permissions: const <String>['view_activity'],
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Invite a Guardian', style: AppTextStyles.title),
            const SizedBox(height: 6),
            Text(
              'They must already be a HamQadam member. Their member ID is on their profile.',
              style: AppTextStyles.caption.copyWith(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _idCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Guardian member ID',
                hintText: 'e.g. 16',
                border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _relCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Relationship',
                hintText: 'e.g. Father, Elder Brother',
                border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
              ),
              items: _roles
                  .map((String r) => DropdownMenuItem<String>(
                        value: r,
                        child: Text(r == 'wali' ? 'Wali' : 'Guardian'),
                      ))
                  .toList(),
              onChanged: (String? v) => setState(() => _role = v ?? 'guardian'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: Obx(() => ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.regAccent,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                    ),
                    onPressed: widget.controller.busy.value ? null : _submit,
                    child: widget.controller.busy.value
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Send Invitation',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
