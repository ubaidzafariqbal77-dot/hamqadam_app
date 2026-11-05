/// One home-banner slide from `GET /ads-banner` (or a bundled fallback).
class AdSlideModel {
  const AdSlideModel({
    required this.eyebrow,
    required this.title,
    required this.highlight,
    required this.subtitle,
    this.buttonLabel = '',
    this.buttonUrl,
    this.imageUrl,
    this.assetImage,
  });

  final String eyebrow;
  final String title;
  final String highlight;
  final String subtitle;
  final String buttonLabel;
  final String? buttonUrl;

  /// Admin-uploaded artwork; [assetImage] is the bundled fallback.
  final String? imageUrl;
  final String? assetImage;

  factory AdSlideModel.fromJson(Map<String, dynamic> json) {
    String s(String k) => (json[k] ?? '').toString().trim();
    return AdSlideModel(
      eyebrow: s('eyebrow'),
      title: s('title'),
      highlight: s('highlight'),
      subtitle: s('subtitle'),
      buttonLabel: s('button_label'),
      buttonUrl: s('button_url').isEmpty ? null : s('button_url'),
      imageUrl: s('image_url').isEmpty ? null : s('image_url'),
    );
  }
}
