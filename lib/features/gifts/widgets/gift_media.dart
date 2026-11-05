import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';

import '../../../constants/app_colors.dart';
import '../../../core/services/gift_asset_cache.dart';
import '../../../models/gift_model.dart';

/// Gift thumbnail from the admin-uploaded URL. Gifts are served by the
/// backend only; without a URL a gift glyph stands in.
class GiftThumbnail extends StatelessWidget {
  const GiftThumbnail({super.key, required this.gift, this.size, this.fit = BoxFit.contain});

  final GiftModel gift;
  final double? size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final Widget fallback =
        Icon(Icons.card_giftcard_rounded, color: AppColors.regAccent, size: (size ?? 40) * 0.6);
    final String? url = gift.thumbnailUrl;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: fit,
        placeholder: (_, _) => SizedBox(width: size, height: size),
        errorWidget: (_, _, _) => fallback,
      );
    }
    return SizedBox(width: size, height: size, child: Center(child: fallback));
  }
}

/// Plays the gift's animation in whatever format the admin uploaded
/// (Lottie, GIF, SVGA or MP4). Falls back to the thumbnail while loading
/// or on error.
class GiftAnimation extends StatelessWidget {
  const GiftAnimation({super.key, required this.gift, required this.size});

  final GiftModel gift;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget thumb = GiftThumbnail(gift: gift, size: size);
    final String? url = gift.animationUrl;

    if (url == null) {
      // No backend animation: show the thumbnail.
      return thumb;
    }

    switch (gift.mediaType) {
      case 'gif':
        return CachedNetworkImage(
          imageUrl: url,
          cacheManager: GiftAssetCache.instance.manager,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholder: (_, _) => thumb,
          errorWidget: (_, _, _) => thumb,
        );
      case 'svga':
        return SizedBox(width: size, height: size, child: SVGAEasyPlayer(resUrl: url));
      case 'mp4':
        return _GiftVideo(url: url, size: size, placeholder: thumb);
      default:
        return Lottie.network(url,
            width: size, height: size, fit: BoxFit.contain, errorBuilder: (_, _, _) => thumb);
    }
  }
}

class _GiftVideo extends StatefulWidget {
  const _GiftVideo({required this.url, required this.size, required this.placeholder});

  final String url;
  final double size;
  final Widget placeholder;

  @override
  State<_GiftVideo> createState() => _GiftVideoState();
}

class _GiftVideoState extends State<_GiftVideo> {
  late final VideoPlayerController _ctrl =
      VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl.setLooping(true);
    _ctrl.setVolume(0);
    _ctrl.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _ctrl.play();
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return widget.placeholder;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _ctrl.value.size.width,
          height: _ctrl.value.size.height,
          child: VideoPlayer(_ctrl),
        ),
      ),
    );
  }
}
