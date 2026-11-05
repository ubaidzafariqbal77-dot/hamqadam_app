import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../models/gift_model.dart';
import '../utils/app_logger.dart';

/// Keeps gift thumbnails and animations on disk so a received gift plays
/// instantly. Shares [DefaultCacheManager] with CachedNetworkImage, so
/// thumbnails prefetched here are the same files the image widgets read.
class GiftAssetCache {
  GiftAssetCache._();

  static final GiftAssetCache instance = GiftAssetCache._();

  /// Gift media is admin-managed and rarely replaced (a new upload gets a new
  /// file name), so keep it for a long time.
  /// Exposed so GIF widgets read from the same store.
  CacheManager get manager => _cache;

  final CacheManager _cache = CacheManager(Config(
    'giftAssets',
    stalePeriod: const Duration(days: 60),
    maxNrOfCacheObjects: 400,
  ));

  final Set<String> _queued = <String>{};
  final List<String> _queue = <String>[];
  bool _running = false;

  /// Downloads every gift's thumbnail, then every animation, one at a time
  /// in the background. URLs already queued or cached are skipped.
  void prefetchAll(Iterable<GiftModel> gifts) {
    final List<GiftModel> list = gifts.toList();
    for (final GiftModel g in list) {
      _enqueue(g.thumbnailUrl, thumbnail: true);
    }
    for (final GiftModel g in list) {
      _enqueue(g.animationUrl);
    }
    _drain();
  }

  /// A single gift (e.g. one just received) jumps the queue.
  void prefetch(GiftModel gift) {
    _enqueue(gift.animationUrl, front: true);
    _enqueue(gift.thumbnailUrl, thumbnail: true, front: true);
    _drain();
  }

  /// The local file if this animation is already cached, else null.
  Future<File?> cachedFile(String url) async => (await _cache.getFileFromCache(url))?.file;

  /// The local file, downloading now if needed.
  Future<File> file(String url) => _cache.getSingleFile(url);

  void _enqueue(String? url, {bool thumbnail = false, bool front = false}) {
    if (url == null) return;
    // Thumbnails go to the image cache CachedNetworkImage reads from.
    final String key = thumbnail ? 'thumb|$url' : url;
    if (!_queued.add(key)) return;
    front ? _queue.insert(0, key) : _queue.add(key);
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    while (_queue.isNotEmpty) {
      final String key = _queue.removeAt(0);
      final bool thumb = key.startsWith('thumb|');
      final String url = thumb ? key.substring(6) : key;
      try {
        final CacheManager m = thumb ? DefaultCacheManager() : _cache;
        if (await m.getFileFromCache(url) == null) await m.downloadFile(url);
      } catch (e) {
        _queued.remove(key); // allow a retry on the next prefetch
        AppLogger.w('Gift asset prefetch failed: $url $e');
      }
    }
    _running = false;
  }
}
