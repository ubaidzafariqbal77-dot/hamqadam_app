import 'dart:convert';

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

/// Tenor-powered GIF picker.
///
/// Uses Tenor's public v2 API. The key below is Tenor's long-standing public
/// "test" key — swap `tenorApiKey` for a registered app key before wide
/// release if rate limits ever bite. Results are media-format agnostic: the
/// response is walked for the smallest `gif` rendition for the preview and a
/// mid-size `gif` for sending.
class ChatGifPicker extends StatefulWidget {
  const ChatGifPicker({super.key, required this.onPick});

  /// Called with the chosen GIF's full animated URL.
  final ValueChanged<String> onPick;

  @override
  State<ChatGifPicker> createState() => _ChatGifPickerState();
}

class _ChatGifPickerState extends State<ChatGifPicker> {
  static const String _tenorApiKey = 'LIVDSRZULELA'; // Tenor public apps key
  static const String _baseUrl = 'https://tenor.googleapis.com/v2/search';

  final TextEditingController _search = TextEditingController();
  final List<GifItem> _gifs = <GifItem>[];
  bool _loading = false;
  String _error = '';
  int _nextPos = 0; // Tenor pagination token

  @override
  void initState() {
    super.initState();
    _searchGifs('trending');
  }

  Future<void> _searchGifs(String query, {bool append = false}) async {
    setState(() {
      _loading = true;
      _error = '';
      if (!append) _gifs.clear();
    });
    try {
      final Response<dynamic> res = await Dio().get<Map<String, dynamic>>(
        _baseUrl,
        queryParameters: <String, dynamic>{
          'key': _tenorApiKey,
          'q': query,
          'limit': 24,
          'media_filter': 'gif',
          'client_key': 'hamqadam_flutter',
          if (append && _nextPos > 0) 'pos': _nextPos,
        },
      );
      final Map<String, dynamic> body =
          (res.data is Map) ? res.data as Map<String, dynamic> : <String, dynamic>{};
      final List<dynamic> results = (body['results'] as List<dynamic>?) ?? <dynamic>[];
      final List<GifItem> parsed = <GifItem>[];
      for (final dynamic row in results) {
        if (row is! Map<String, dynamic>) continue;
        final List<dynamic> formats =
            (row['media_formats'] as Map<String, dynamic>?)?.values.toList() ?? <dynamic>[];
        String? full;
        String? preview;
        for (final dynamic f in formats) {
          if (f is! Map<String, dynamic>) continue;
          final String url = (f['url'] ?? '').toString();
          if (url.endsWith('.gif')) {
            full ??= url;
            // Anything under ~1MB works as a preview; the smallest wins.
            final int size = (f['size'] as num?)?.toInt() ?? 1 << 30;
            if (size < 300000) preview ??= url;
          }
        }
        if (full != null) {
          parsed.add(GifItem(previewUrl: preview ?? full, fullUrl: full));
        }
      }
      _nextPos = int.tryParse('${body['next'] ?? 0}') ?? 0;
      if (!mounted) return;
      setState(() {
        _gifs.addAll(parsed);
        _loading = false;
        if (_gifs.isEmpty) _error = 'No GIFs found';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'GIFs load nahi huin — internet check karein';
      });
    }
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
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
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
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
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
                                  child: const Icon(Icons.gif_rounded, color: AppColors.primary),
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
