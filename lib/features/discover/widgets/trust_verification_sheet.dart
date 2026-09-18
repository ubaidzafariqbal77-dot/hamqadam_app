import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../constants/api_endpoints.dart';
import '../../../core/api/api_client.dart';
import '../../../models/profile_model.dart';

/// Trust & Verification dialog for a PUBLIC profile (Discover cards).
///
/// Tapping the blue verified tick on a Discover card opens this sheet, which
/// pulls `GET /profiles/{id}/trust` — the same server-computed checklist the
/// member's own profile shows. Deliberately lightweight on the backend: it
/// does NOT consume a profile-view coin, because glancing at verification
/// badges is not a "profile view".
class TrustVerificationSheet extends StatefulWidget {
  const TrustVerificationSheet({
    super.key,
    required this.profileId,
    this.name,
    this.photoUrl,
  });

  final int profileId;
  final String? name;
  final String? photoUrl;

  /// Glass-styled modal used by every Discover card's verified tick.
  static Future<void> show(
    BuildContext context, {
    required int profileId,
    String? name,
    String? photoUrl,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrustVerificationSheet(
        profileId: profileId,
        name: name,
        photoUrl: photoUrl,
      ),
    );
  }

  @override
  State<TrustVerificationSheet> createState() => _TrustVerificationSheetState();
}

class _TrustVerificationSheetState extends State<TrustVerificationSheet> {
  late Future<ProfileTrustChecks> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ProfileTrustChecks> _load() async {
    final ApiClient client = Get.find<ApiClient>();
    final res = await client.get(ApiEndpoints.profileTrust(widget.profileId));
    return ProfileTrustChecks.fromJson(res.dataMap);
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = dark ? AppColors.darkSurface : Colors.white;
    final Color ink =
        dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color muted =
        dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppRadius.xlAll,
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: FutureBuilder<ProfileTrustChecks>(
          future: _future,
          builder: (BuildContext context,
              AsyncSnapshot<ProfileTrustChecks> snap) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _SheetHeader(
                  name: widget.name,
                  photoUrl: widget.photoUrl,
                  ink: ink,
                  muted: muted,
                  dark: dark,
                ),
                const Divider(height: 1),
                Flexible(
                  child: snap.connectionState == ConnectionState.waiting
                      ? _LoadingRows()
                      : snap.hasError
                          ? _ErrorPane(
                              message: 'Could not load verification details.',
                              onRetry: _retry,
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
                              child: _ChecklistBody(
                                checks: snap.data ?? const ProfileTrustChecks(),
                                ink: ink,
                                muted: muted,
                              ),
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.name,
    required this.photoUrl,
    required this.ink,
    required this.muted,
    required this.dark,
  });

  final String? name;
  final String? photoUrl;
  final Color ink;
  final Color muted;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                ? NetworkImage(photoUrl!)
                : null,
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? Icon(Icons.person_rounded, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name?.isNotEmpty == true ? name! : 'Member',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.copyWith(color: ink),
                ),
                Text(
                  'Trust & Verification',
                  style: AppTextStyles.caption.copyWith(color: muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Checklist body — same rows as the profile's Trust & Verification card.
// ---------------------------------------------------------------------------

class _ChecklistBody extends StatelessWidget {
  const _ChecklistBody({required this.checks, required this.ink, required this.muted});

  final ProfileTrustChecks checks;
  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _Row(label: 'Identity', passed: checks.identity, passedText: 'CNIC verified', failedText: 'Not verified', ink: ink, muted: muted),
        _Row(label: 'Face', passed: checks.face, passedText: 'Selfie verified', failedText: 'Selfie not verified', ink: ink, muted: muted),
        _Row(label: 'Liveness', passed: checks.liveness, passedText: 'Live verification passed', failedText: 'Not yet verified', ink: ink, muted: muted),
        _Row(label: 'Contact', passed: checks.phone, passedText: 'Phone verified', failedText: 'Phone not verified', ink: ink, muted: muted),
        _Row(label: 'Email', passed: checks.email, passedText: 'Email verified', failedText: 'Email not verified', ink: ink, muted: muted),
        _Row(label: 'Profile', passed: checks.profile, passedText: 'Admin reviewed', failedText: 'Awaiting review', ink: ink, muted: muted),
        _Row(label: 'Intent', passed: checks.intent, passedText: 'Marriage intention confirmed', failedText: 'Not on record', ink: ink, muted: muted),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.passed,
    required this.passedText,
    required this.failedText,
    required this.ink,
    required this.muted,
  });

  final String label;
  final bool? passed;
  final String passedText;
  final String failedText;
  final Color ink;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (passed) {
      true => (Icons.check_circle_rounded, AppColors.success),
      false => (Icons.cancel_rounded, AppColors.error),
      null => (Icons.remove_circle_outline_rounded, muted),
    };
    final String text = passed == true ? passedText : failedText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: AppTextStyles.bodyStrong
                  .copyWith(color: ink, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: passed == true ? muted : ink,
                fontWeight: passed == true ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading / error panes
// ---------------------------------------------------------------------------

class _LoadingRows extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: List<Widget>.generate(
          7,
          (int i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: <Widget>[
                Container(
                  width: 84,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  width: 140,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.cloud_off_rounded,
              size: 34, color: Theme.of(context).hintColor),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption
                .copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
