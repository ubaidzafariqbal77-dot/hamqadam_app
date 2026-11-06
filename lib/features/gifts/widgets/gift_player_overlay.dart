import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';

import '../../../constants/app_colors.dart';
import '../../../core/services/gift_asset_cache.dart';
import '../../../models/gift_model.dart';
import 'gift_media.dart';

/// TikTok-live style playback: the gift plays once, full screen over a dim
/// backdrop, with its sound (MP4 audio track / SVGA embedded audio), then
/// closes itself. Tap anywhere to dismiss early.
class GiftPlayerOverlay extends StatefulWidget {
  const GiftPlayerOverlay({super.key, required this.gift, this.caption});

  final GiftModel gift;
  final String? caption;

  static Future<void> show(BuildContext context, GiftModel gift, {String? caption}) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Gift',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => GiftPlayerOverlay(gift: gift, caption: caption),
      transitionBuilder: (_, Animation<double> a, _, Widget child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1).animate(a), child: child),
      ),
    );
  }

  @override
  State<GiftPlayerOverlay> createState() => _GiftPlayerOverlayState();
}

class _GiftPlayerOverlayState extends State<GiftPlayerOverlay> with TickerProviderStateMixin {
  /// Formats without an "ended" signal (GIF) close after this long.
  static const Duration _fallbackLength = Duration(seconds: 4);

  VideoPlayerController? _video;
  SVGAAnimationController? _svga;
  AnimationController? _lottie;
  Timer? _timer;
  File? _lottieFile;
  bool _closed = false;
  bool _failed = false;

  GiftModel get _gift => widget.gift;

  @override
  void initState() {
    super.initState();
    final String? url = _gift.animationUrl;
    switch (url == null ? 'lottie' : _gift.mediaType) {
      case 'mp4':
        // Local file from the gift cache — no streaming delay once warmed.
        GiftAssetCache.instance.file(url!).then((File f) {
          if (!mounted) return null;
          setState(() => _video = VideoPlayerController.file(f));
          return _video!.initialize();
        }).then((_) {
          if (!mounted || _video == null) return;
          setState(() {});
          // Safety net: close right after the clip's length even if the
          // player never reports a clean "ended" state.
          _timer = Timer(_video!.value.duration + const Duration(milliseconds: 400), _close);
          _video!
            ..setVolume(1)
            ..addListener(_onVideoTick)
            ..play();
        }).catchError((Object _) => _fail());
      case 'svga':
        _svga = SVGAAnimationController(vsync: this);
        GiftAssetCache.instance
            .file(url!)
            .then((File f) async => SVGAParser.shared.decodeFromBuffer(await f.readAsBytes()))
            .then((MovieEntity item) {
          if (!mounted) return;
          _svga!.videoItem = item;
          _svga!.forward().whenComplete(_close);
        }).catchError((Object _) => _fail());
      case 'gif':
        _timer = Timer(_fallbackLength, _close);
      default:
        _lottie = AnimationController(vsync: this);
        if (url != null) {
          GiftAssetCache.instance.file(url).then((File f) {
            if (mounted) setState(() => _lottieFile = f);
          }).catchError((Object _) => _fail());
        }
    }
  }

  void _onVideoTick() {
    final VideoPlayerValue v = _video!.value;
    if (v.isInitialized &&
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 150)) {
      _close();
    }
  }

  void _fail() {
    if (!mounted) return;
    setState(() => _failed = true);
    _timer = Timer(const Duration(seconds: 2), _close);
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    _svga?.dispose();
    _lottie?.dispose();
    super.dispose();
  }

  void _onLottieLoaded(LottieComposition c) {
    _lottie!
      ..duration = c.duration
      ..forward().whenComplete(_close);
  }

  Widget _player(Size screen) {
    final double side = screen.width;
    final Widget thumb = GiftThumbnail(gift: _gift, size: side * 0.6);
    if (_failed) return thumb;
    final String? url = _gift.animationUrl;

    if (_gift.animationUrl != null && _gift.mediaType == 'mp4') {
      if (_video == null || !_video!.value.isInitialized) return const CircularProgressIndicator(color: Colors.white);
      // Fill the whole phone screen (cropping edges if the ratio differs).
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _video!.value.size.width,
            height: _video!.value.size.height,
            child: VideoPlayer(_video!),
          ),
        ),
      );
    }
    if (_svga != null) {
      return SizedBox.expand(child: SVGAImage(_svga!, fit: BoxFit.cover));
    }
    if (_lottie != null) {
      return url == null
          ? Lottie.asset(_gift.animatedAsset,
              controller: _lottie, width: side, onLoaded: _onLottieLoaded, errorBuilder: (_, _, _) => thumb)
          : _lottieFile == null
              ? const CircularProgressIndicator(color: Colors.white)
              : Lottie.file(_lottieFile!,
                  controller: _lottie, width: side, onLoaded: _onLottieLoaded, errorBuilder: (_, _, _) => thumb);
    }
    return CachedNetworkImage(imageUrl: url!, cacheManager: GiftAssetCache.instance.manager, width: side, fit: BoxFit.contain, errorWidget: (_, _, _) => thumb);
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Full-bleed: the gift covers the entire screen, edge to edge.
              Positioned.fill(child: Center(child: _player(screen))),
              Positioned(
                bottom: MediaQuery.paddingOf(context).bottom + 24,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.card_giftcard_rounded, color: AppColors.gold, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.caption ?? _gift.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
