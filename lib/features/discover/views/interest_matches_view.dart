import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../repositories/discover_extra_repository.dart';
import '../../auth/views/home_view.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/skeleton.dart';
import '../../../widgets/state_widgets.dart';
import '../widgets/discover_profile_card.dart';

/// Interest-Based Recommendations.
///
/// `GET /matches/interest-based` ranks members by how much of the viewer's own
/// profile they share — hobbies, interests, life values, love language, family
/// values, languages — and sends back WHICH words matched, so every card can
/// say why it is here instead of showing a bare percentage.
///
/// When the viewer has none of those filled in, the API says so
/// (`reason: no_profile_interests`) and this screen sends them to fill it in
/// rather than showing an empty list with no explanation.
class InterestMatchesView extends StatefulWidget {
  const InterestMatchesView({super.key});

  @override
  State<InterestMatchesView> createState() => _InterestMatchesViewState();
}

class _InterestMatchesViewState extends State<InterestMatchesView> {
  final DiscoverExtraRepository _repo = Get.find<DiscoverExtraRepository>();

  InterestMatches? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final InterestMatches data = await _repo.fetchInterestMatches(perPage: 30);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PremiumAppBar(
        title: 'Interest-Based',
        subtitle: 'Recommended from what you both care about',
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.chatCanvasTop,
              AppColors.chatCanvasBottom,
            ],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const SkeletonList();
    if (_error != null) {
      return ErrorStateWidget(message: _error, onRetry: _load);
    }

    final InterestMatches data = _data ??
        const InterestMatches(
          matches: <SearchProfileModel>[],
          yourInterests: <String>[],
        );

    if (data.reason == 'no_profile_interests' || data.yourInterests.isEmpty) {
      return _NoInterestsYet(onRefresh: _load);
    }

    if (data.matches.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: <Widget>[
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'No shared-interest matches yet',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyStrong.copyWith(
                fontSize: 16,
                color: AppColors.roseTitleInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Nobody currently matches on your interests. New members join '
              'every day — pull down to check again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                color: AppColors.chatPreviewInk,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          _YourInterests(words: data.yourInterests),
          const SizedBox(height: AppSpacing.sm),
          ...data.matches.map((SearchProfileModel profile) {
            final int score = profile.interestScore ?? 0;
            final String shared = profile.sharedInterests.take(5).join(', ');
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: DiscoverProfileCard(
                profile: profile,
                badgeLabel: score > 0 ? '$score% interests' : null,
                badgeIcon: Icons.interests_rounded,
                footnote: shared.isEmpty ? null : 'You both like: $shared',
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// The words this ranking is built from — the member's own, straight from the
/// API's `your_interests`, so the screen explains the list it produced.
class _YourInterests extends StatelessWidget {
  const _YourInterests({required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.chatCardFill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.chatCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Matched against your interests',
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: 13.5,
              color: AppColors.roseTitleInk,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: words.take(12).map((String word) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.roseSelectedFill,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  word,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    color: AppColors.chatPillInk,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _NoInterestsYet extends StatelessWidget {
  const _NoInterestsYet({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: <Widget>[
          const SizedBox(height: AppSpacing.xxl),
          const Icon(
            Icons.interests_outlined,
            size: 44,
            color: AppColors.chatTimeInk,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add your interests first',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: 16.5,
              color: AppColors.roseTitleInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Recommendations are built from your hobbies, interests, values '
            'and languages. Fill a few in and this list will appear.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              color: AppColors.chatPreviewInk,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              // Interests are edited from the member's own profile, so this
              // closes the screen and lands them on the Profile tab rather
              // than inventing a second editing route.
              onPressed: () {
                Get.back<void>();
                HomeView.goToTab(3);
              },
              child: const Text('Complete my profile'),
            ),
          ),
        ],
      ),
    );
  }
}
