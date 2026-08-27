import 'search_filter_profile_model.dart';

/// Summary and quota information for profile views.
class ProfileViewSummary {
  const ProfileViewSummary({
    this.remainingViews = 0,
    this.usedViews = 0,
    this.packageValidity,
    this.isActive = false,
    this.currentPackageId,
    this.packageName,
  });

  final int remainingViews;
  final int usedViews;
  final String? packageValidity;
  final bool isActive;
  final dynamic currentPackageId;
  final String? packageName;

  factory ProfileViewSummary.fromJson(Map<String, dynamic> json) {
    final dynamic pkg = json['current_package'];
    final dynamic pkgId = pkg is Map ? pkg['id'] : json['current_package_id'];
    final String? pkgName = pkg is Map ? pkg['name']?.toString() : null;

    return ProfileViewSummary(
      remainingViews: json['remaining_profile_viewer_view'] as int? ??
          int.tryParse('${json['remaining_profile_viewer_view']}') ??
          0,
      usedViews: json['used_profile_views'] as int? ??
          int.tryParse('${json['used_profile_views']}') ??
          0,
      packageValidity: json['package_validity'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      currentPackageId: pkgId,
      packageName: pkgName,
    );
  }
}

/// A single profile view record (either viewed by current user or received).
class ProfileViewItem {
  const ProfileViewItem({
    required this.id,
    this.viewedAt,
    this.viewType,
    required this.profile,
  });

  final int id;
  final DateTime? viewedAt;
  final String? viewType; // 'received' | 'viewed'
  final SearchProfileModel profile;

  factory ProfileViewItem.fromJson(Map<String, dynamic> json) {
    final dynamic rawProfile = json['profile'] ?? json['user'] ?? json['member'];
    final SearchProfileModel profileModel;
    if (rawProfile is Map<String, dynamic>) {
      profileModel = SearchProfileModel.fromJson(rawProfile);
    } else {
      profileModel = SearchProfileModel(
        id: json['profile_id'] as int? ?? json['id'] as int? ?? 0,
        name: json['name'] as String?,
        photo: json['photo'] as String?,
      );
    }

    return ProfileViewItem(
      id: json['id'] as int? ?? profileModel.id,
      viewedAt: json['viewed_at'] != null
          ? DateTime.tryParse(json['viewed_at'] as String)
          : null,
      viewType: json['view_type'] as String?,
      profile: profileModel,
    );
  }
}

/// Paginated list of profile views with metadata and summary.
class ProfileViewsPage {
  const ProfileViewsPage({
    required this.items,
    this.summary,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.perPage = 20,
  });

  final List<ProfileViewItem> items;
  final ProfileViewSummary? summary;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  bool get hasMore => currentPage < lastPage;

  factory ProfileViewsPage.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json['data'];
    final List<dynamic> list = rawData is List ? rawData : <dynamic>[];

    final dynamic rawSummary = json['summary'] ?? json['meta']?['summary'];
    final dynamic rawMeta = json['meta'];

    return ProfileViewsPage(
      items: list
          .whereType<Map<String, dynamic>>()
          .map(ProfileViewItem.fromJson)
          .toList(),
      summary: rawSummary is Map<String, dynamic>
          ? ProfileViewSummary.fromJson(rawSummary)
          : null,
      currentPage: rawMeta is Map ? (rawMeta['current_page'] as int? ?? 1) : 1,
      lastPage: rawMeta is Map ? (rawMeta['last_page'] as int? ?? 1) : 1,
      total: rawMeta is Map ? (rawMeta['total'] as int? ?? list.length) : list.length,
      perPage: rawMeta is Map ? (rawMeta['per_page'] as int? ?? 20) : 20,
    );
  }
}
