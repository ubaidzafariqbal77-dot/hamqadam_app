import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';

/// Result row for the GIF picker grid.
class GifItem {
  const GifItem({required this.previewUrl, required this.fullUrl});

  /// Small still frame for the grid (fast loading).
  final String previewUrl;

  /// Full animated GIF URL — this is what gets sent and rendered in the bubble.
  final String fullUrl;
}

/// Giphy-powered GIF picker.
///
/// Tenor shut down its public API (the old `LIVDSRZULELA` key now returns
/// API_KEY_INVALID and new keys are no longer issued), so the picker moved to
/// Giphy's v1 REST API. `rating: pg` keeps results clean for a matrimonial
/// app. The preview is the 200px `fixed_width_downsampled` rendition; the
/// full GIF is `downsized_medium` (mobile-friendly size) with `original` as
/// fallback.
class ChatGifPicker extends StatefulWidget {
  const ChatGifPicker({super.key, required this.onPick});

  /// Called with the chosen GIF's full animated URL.
  final ValueChanged<String> onPick;

  @override
  State<ChatGifPicker> createState() => _ChatGifPickerState();
}

class _ChatGifPickerState extends State<ChatGifPicker> {
  static const String _giphyApiKey = 'GlVGYHkr3WSBnllca54iNt0yFbjz7L65';
  static const String _searchUrl = 'https://api.giphy.com/v1/gifs/search';
  static const String _trendingUrl = 'https://api.giphy.com/v1/gifs/trending';
  static const int _pageSize = 24;

  final TextEditingController _search = TextEditingController();
  final List<GifItem> _gifs = <GifItem>[];
  bool _loading = false;
  bool _hasMore = true;
  String _error = '';
  int _offset = 0; // Giphy pagination cursor

  @override
  void initState() {
    super.initState();
    _searchGifs('trending');
  }

  Future<void> _searchGifs(String query, {bool append = false}) async {
    setState(() {
      _loading = true;
      _error = '';
      if (!append) {
        _gifs.clear();
        _offset = 0;
        _hasMore = true;
      }
    });
    try {
      final bool trending = query == 'trending';
      final Response<dynamic> res = await Dio().get<Map<String, dynamic>>(
        trending ? _trendingUrl : _searchUrl,
        queryParameters: <String, dynamic>{
          'api_key': _giphyApiKey,
          'limit': _pageSize,
          'rating': 'pg',
          'bundle': 'messaging_non_clips',
          if (!trending) 'q': query,
          'offset': _offset,
        },
      );
      final Map<String, dynamic> body =
          (res.data is Map) ? res.data as Map<String, dynamic> : <String, dynamic>{};
      final List<dynamic> results = (body['data'] as List<dynamic>?) ?? <dynamic>[];
      final Map<String, dynamic> pagination =
          (body['pagination'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final List<GifItem> parsed = <GifItem>[];
      for (final dynamic row in results) {
        if (row is! Map<String, dynamic>) continue;
        final Map<String, dynamic> images =
            (row['images'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        String? preview = _renditionUrl(
          images,
          const <String>['fixed_width_downsampled', 'fixed_width', 'fixed_height'],
        );
        String? full = _renditionUrl(images, const <String>['downsized_medium']) ??
            _renditionUrl(images, const <String>['original']);
        preview ??= full;
        if (full != null) {
          parsed.add(GifItem(previewUrl: preview!, fullUrl: full));
        }
      }
      _offset += parsed.length;
      final int total = (pagination['total_count'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      setState(() {
        _gifs.addAll(parsed);
        _loading = false;
        _hasMore = total == 0 || _offset < total;
        if (_gifs.isEmpty) _error = 'No GIFs found';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load GIFs — check your internet connection';
      });
    }
  }

  /// Walks the candidate rendition names in order and returns the first
  /// non-empty `.gif` URL.
  static String? _renditionUrl(Map<String, dynamic> images, List<String> names) {
    for (final String name in names) {
      final dynamic rendition = images[name];
      if (rendition is! Map<String, dynamic>) continue;
      final String url = (rendition['url'] ?? '').toString();
      if (url.isNotEmpty && url.endsWith('.gif')) return url;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightDivider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (String q) => _searchGifs(q.trim().isEmpty ? 'trending' : q.trim()),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search GIFs…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primaryDark),
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _loading && _gifs.isEmpty
                ? Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                : _error.isNotEmpty && _gifs.isEmpty
                    ? Center(
                        child: Text(_error,
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        itemCount: _gifs.length,
                        itemBuilder: (BuildContext _, int i) {
                          final GifItem gif = _gifs[i];
                          // Pre-fetch the next page as the user nears the end.
                          if (i >= _gifs.length - 6 && !_loading && _hasMore) {
                            _searchGifs(
                              _search.text.trim().isEmpty ? 'trending' : _search.text.trim(),
                              append: true,
                            );
                          }
                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onPick(gif.fullUrl);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                gif.previewUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.lightSurfaceAlt,
                                  child: const Icon(Icons.gif_rounded, color: AppColors.primaryDark),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
