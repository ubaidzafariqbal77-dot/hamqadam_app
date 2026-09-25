import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_text_styles.dart';
import '../../../controllers/swipe_controller.dart';
import '../../../models/search_filter_profile_model.dart';
import '../../../widgets/premium_app_bar.dart';
import '../../../widgets/state_widgets.dart';
import '../widgets/discover_profile_card.dart';
import '../widgets/public_profile_detail_sheet.dart';

/// Swipe Matching.
///
/// One card at a time, judged with a drag or the two buttons underneath; the
/// deck, the counters and the mutual-match answer all come from
/// `GET /matches/swipe-deck` / `POST /matches/swipe`, so a member who swipes
/// here and again on another device never sees a card they already judged.
///
/// Passing and liking are both recorded, but neither spends coins: sending an
/// Express Interest stays an explicit action (see the Interest-Based screen and
/// the profile sheet), because silently charging for a gesture would take coins
/// out of the balance on a mis-tap.
class SwipeMatchingView extends StatefulWidget {
  const SwipeMatchingView({super.key});

  @override
  State<SwipeMatchingView> createState() => _SwipeMatchingViewState();
}

class _SwipeMatchingViewState extends State<SwipeMatchingView> {
  final SwipeController _controller = Get.find<SwipeController>();

  /// Live horizontal drag of the top card, in pixels.
  double _dx = 0;
  bool _dragging = false;

  static const double _threshold = 110;

  @override
  void initState() {
    super.initState();
    // The match celebration is owned by the controller, which knows whether the
    // server called it a match; the screen only shows it.
    _controller.onMatch = _celebrate;
  }

  @override
  void dispose() {
    _controller.onMatch = null;
    super.dispose();
  }

  void _celebrate(SearchProfileModel profile) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Text("It's a match!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: (profile.photo ?? '').isNotEmpty
                  ? NetworkImage(profile.photo!)
                  : null,
              child: (profile.photo ?? '').isEmpty
                  ? Text(
                      profile.initial,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${profile.displayName} liked you too.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(fontSize: 14),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep swiping'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              PublicProfileDetailSheet.show(
                context,
                profileId: profile.id,
                name: profile.name,
                photo: profile.photo,
                searchProfile: profile,
              );
            },
            child: const Text('View profile'),
          ),
        ],
      ),
    );
  }

  void _onDragEnd(double dx) {
    setState(() {
      _dragging = false;
      _dx = 0;
    });
    final SearchProfileModel? card = _controller.topCard;
    if (card == null) return;
    if (dx >= _threshold) {
      _controller.swipe(card, like: true);
    } else if (dx <= -_threshold) {
      _controller.swipe(card, like: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PremiumAppBar(
        title: 'Swipe Matching',
        subtitle: 'Like or pass, one profile at a time',
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
        child: Obx(() {
          if (_controller.loading.value && !_controller.hasCards) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (_controller.error.value.isNotEmpty && !_controller.hasCards) {
            return ErrorStateWidget(
              message: _controller.error.value,
              onRetry: _controller.loadDeck,
            );
          }
          if (!_controller.hasCards) return _EmptyDeck(controller: _controller);

          final SearchProfileModel card = _controller.topCard!;
          final int nextIndex = _controller.deck.length - 2;
          final SearchProfileModel? behind =
              nextIndex >= 0 ? _controller.deck[nextIndex] : null;

          return Column(
            children: <Widget>[
              _Counters(controller: _controller),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      if (behind != null)
                        Transform.scale(
                          scale: 0.94,
                          child: Opacity(
                            opacity: 0.55,
                            child: DiscoverProfileCard(profile: behind),
                          ),
                        ),
                      GestureDetector(
                        onPanStart: (_) => setState(() => _dragging = true),
                        onPanUpdate: (DragUpdateDetails details) =>
                            setState(() => _dx += details.delta.dx),
                        onPanEnd: (DragEndDetails _) {
                          _onDragEnd(_dx);
                          _dx = 0;
                        },
                        child: Transform.translate(
                          offset: Offset(_dragging ? _dx : 0, 0),
                          child: Transform.rotate(
                            angle: (_dragging ? _dx : 0) / 1400,
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: <Widget>[
                                DiscoverProfileCard(profile: card),
                                if (_dragging && _dx.abs() > 30)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.lg,
                                    ),
                                    child: _SwipeHint(like: _dx > 0),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _DeckActions(
                controller: _controller,
                onPass: () => _controller.swipe(card, like: false),
                onLike: () => _controller.swipe(card, like: true),
                onOpen: () => PublicProfileDetailSheet.show(
                  context,
                  profileId: card.id,
                  name: card.name,
                  photo: card.photo,
                  searchProfile: card,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Likes sent · matches · cards left, straight from the API counters.
class _Counters extends StatelessWidget {
  const _Counters({required this.controller});

  final SwipeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final Map<String, int> s = controller.summary;
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _Counter(label: 'Likes sent', value: s['likes_sent'] ?? 0),
            _Counter(label: 'Matches', value: s['matches'] ?? 0),
            _Counter(
              label: 'In deck',
              value: controller.deck.length + controller.remaining.value,
            ),
          ],
        ),
      );
    });
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          '$value',
          style: AppTextStyles.title.copyWith(
            fontSize: 19,
            color: AppColors.roseTitleInk,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 11.5,
            color: AppColors.chatTimeInk,
          ),
        ),
      ],
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.like});

  final bool like;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: like ? -0.18 : 0.18,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: like ? AppColors.success : AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(
          like ? 'LIKE' : 'PASS',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _DeckActions extends StatelessWidget {
  const _DeckActions({
    required this.controller,
    required this.onPass,
    required this.onLike,
    required this.onOpen,
  });

  final SwipeController controller;
  final VoidCallback onPass;
  final VoidCallback onLike;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Obx(() {
        final bool busy = controller.swiping.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _ActionButton(
              icon: Icons.replay_rounded,
              colour: AppColors.chatTimeInk,
              tooltip: 'Undo last swipe',
              onTap: busy ? null : controller.undo,
            ),
            _ActionButton(
              icon: Icons.close_rounded,
              colour: AppColors.error,
              tooltip: 'Pass',
              size: 34,
              onTap: busy ? null : onPass,
            ),
            _ActionButton(
              icon: Icons.favorite_rounded,
              colour: AppColors.primary,
              tooltip: 'Like',
              size: 34,
              onTap: busy ? null : onLike,
            ),
            _ActionButton(
              icon: Icons.person_outline_rounded,
              colour: AppColors.roseTitleInk,
              tooltip: 'Open full profile',
              onTap: onOpen,
            ),
          ],
        );
      }),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.colour,
    required this.tooltip,
    this.onTap,
    this.size = 26,
  });

  final IconData icon;
  final Color colour;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Icon(
              icon,
              size: size,
              color: onTap == null
                  ? colour.withValues(alpha: 0.35)
                  : colour,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck({required this.controller});

  final SwipeController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.style_rounded,
              size: 44,
              color: AppColors.chatTimeInk,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'That is everyone for now',
              style: AppTextStyles.bodyStrong.copyWith(
                fontSize: 16.5,
                color: AppColors.roseTitleInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You have judged every profile in the deck. New members appear '
              'here as they join, and you can undo your last swipe or widen the '
              'deck below.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                color: AppColors.chatPreviewInk,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: controller.undo,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Undo'),
                ),
                const SizedBox(width: AppSpacing.sm),
                Obx(() => FilterChip(
                      label: const Text('With photo'),
                      selected: controller.photoOnly.value,
                      onSelected: (_) => controller.togglePhotoOnly(),
                    )),
                const SizedBox(width: AppSpacing.xs),
                Obx(() => FilterChip(
                      label: const Text('Never viewed'),
                      selected: controller.excludeViewed.value,
                      onSelected: (_) => controller.toggleExcludeViewed(),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
