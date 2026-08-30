/// Feature limits and counts included in a subscription plan.
class PaymentPlanFeatures {
  const PaymentPlanFeatures({
    this.coins = 0,
    this.messagingInterests = 0,
    this.photoGallery = 0,
    this.contacts = 0,
    this.profileViewers = 0,
    this.profileImageViews = 0,
    this.galleryImageViews = 0,
    this.autoProfileMatch = false,
    this.autoHoroscopeProfileMatch = false,
  });

  final int coins;
  final int messagingInterests;
  final int photoGallery;
  final int contacts;
  final int profileViewers;
  final int profileImageViews;
  final int galleryImageViews;
  final bool autoProfileMatch;
  final bool autoHoroscopeProfileMatch;

  factory PaymentPlanFeatures.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PaymentPlanFeatures();
    return PaymentPlanFeatures(
      coins: _asInt(json['coins']),
      messagingInterests: _asInt(json['messaging_interests']),
      photoGallery: _asInt(json['photo_gallery']),
      contacts: _asInt(json['contacts']),
      profileViewers: _asInt(json['profile_viewers']),
      profileImageViews: _asInt(json['profile_image_views']),
      galleryImageViews: _asInt(json['gallery_image_views']),
      autoProfileMatch: _asBool(json['auto_profile_match']),
      autoHoroscopeProfileMatch: _asBool(json['auto_horoscope_profile_match']),
    );
  }
}

/// Feature flags enabled in a subscription plan.
class PaymentPlanFeatureFlags {
  const PaymentPlanFeatureFlags({
    this.aiMatching = false,
    this.advancedSearch = false,
  });

  final bool aiMatching;
  final bool advancedSearch;

  factory PaymentPlanFeatureFlags.fromJson(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return PaymentPlanFeatureFlags(
        aiMatching: _asBool(raw['ai_matching']),
        advancedSearch: _asBool(raw['advanced_search']),
      );
    }
    return const PaymentPlanFeatureFlags();
  }
}

/// A subscription plan / package (`GET /payments/plans` or `GET /payments/packages/{id}`).
class PaymentPlanModel {
  const PaymentPlanModel({
    required this.id,
    required this.name,
    this.tier,
    this.price = 0,
    this.validityDays = 0,
    this.isRecurring = false,
    this.features = const PaymentPlanFeatures(),
    this.featureFlags = const PaymentPlanFeatureFlags(),
  });

  final int id;
  final String name;
  final String? tier;
  final num price;
  final int validityDays;
  final bool isRecurring;
  final PaymentPlanFeatures features;
  final PaymentPlanFeatureFlags featureFlags;

  bool get isFree => price == 0 || (tier != null && tier!.toLowerCase() == 'free');

  String get priceFormatted => isFree ? 'Free' : 'PKR ${price.toStringAsFixed(0)}';

  factory PaymentPlanModel.fromJson(Map<String, dynamic> json) {
    return PaymentPlanModel(
      id: _asInt(json['id']),
      name: json['name'] as String? ?? 'Standard Plan',
      tier: json['tier'] as String?,
      price: json['price'] as num? ?? 0,
      validityDays: _asInt(json['validity_days']),
      isRecurring: _asBool(json['is_recurring']),
      features: PaymentPlanFeatures.fromJson(
        json['features'] is Map<String, dynamic> ? json['features'] as Map<String, dynamic> : null,
      ),
      featureFlags: PaymentPlanFeatureFlags.fromJson(json['feature_flags']),
    );
  }
}

/// Remaining allowance in current active package (`GET /payments/current`).
class CurrentPackageRemaining {
  const CurrentPackageRemaining({
    this.coins = 0,
    this.contactView = 0,
    this.profileViewerView = 0,
    this.profileImageView = 0,
    this.galleryImageView = 0,
    this.photoGallery = 0,
  });

  final int coins;
  final int contactView;
  final int profileViewerView;
  final int profileImageView;
  final int galleryImageView;
  final int photoGallery;

  factory CurrentPackageRemaining.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CurrentPackageRemaining();
    return CurrentPackageRemaining(
      coins: _asInt(json['coins']),
      contactView: _asInt(json['contact_view']),
      profileViewerView: _asInt(json['profile_viewer_view']),
      profileImageView: _asInt(json['profile_image_view']),
      galleryImageView: _asInt(json['gallery_image_view']),
      photoGallery: _asInt(json['photo_gallery']),
    );
  }
}

/// Current active package response payload (`GET /payments/current`).
class CurrentPackageData {
  const CurrentPackageData({
    this.currentPackage,
    this.packageValidity,
    this.isActive = false,
    this.remaining = const CurrentPackageRemaining(),
  });

  final PaymentPlanModel? currentPackage;
  final String? packageValidity;
  final bool isActive;
  final CurrentPackageRemaining remaining;

  factory CurrentPackageData.fromJson(Map<String, dynamic> json) {
    final dynamic rawPkg = json['current_package'];
    return CurrentPackageData(
      currentPackage: rawPkg is Map<String, dynamic> ? PaymentPlanModel.fromJson(rawPkg) : null,
      packageValidity: json['package_validity'] as String?,
      isActive: _asBool(json['is_active']),
      remaining: CurrentPackageRemaining.fromJson(
        json['remaining'] is Map<String, dynamic> ? json['remaining'] as Map<String, dynamic> : null,
      ),
    );
  }
}

/// Single feature usage row (`GET /payments/usage`).
class PaymentUsageItem {
  const PaymentUsageItem({
    required this.id,
    required this.feature,
    required this.featureLabel,
    required this.amount,
    this.referenceType,
    this.referenceId,
    this.note,
    this.createdAt,
  });

  final int id;
  final String feature;
  final String featureLabel;
  final int amount;
  final String? referenceType;
  final int? referenceId;
  final String? note;
  final DateTime? createdAt;

  factory PaymentUsageItem.fromJson(Map<String, dynamic> json) {
    return PaymentUsageItem(
      id: _asInt(json['id']),
      feature: json['feature'] as String? ?? '',
      featureLabel: json['feature_label'] as String? ?? 'Usage',
      amount: _asInt(json['amount']),
      referenceType: json['reference_type'] as String?,
      referenceId: _asIntOrNull(json['reference_id']),
      note: json['note'] as String?,
      createdAt: _asDate(json['created_at']),
    );
  }
}

/// Coin usage summary attached to `GET /payments/usage`.
class PaymentUsageSummary {
  const PaymentUsageSummary({
    this.purchasedCoins = 0,
    this.usedCoins = 0,
    this.remainingCoins = 0,
  });

  final int purchasedCoins;
  final int usedCoins;
  final int remainingCoins;

  factory PaymentUsageSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PaymentUsageSummary();
    return PaymentUsageSummary(
      purchasedCoins: _asInt(json['purchased_coins']),
      usedCoins: _asInt(json['used_coins']),
      remainingCoins: _asInt(json['remaining_coins']),
    );
  }
}

/// Paginated response from `GET /payments/usage`.
class PaymentUsagePage {
  const PaymentUsagePage({
    this.items = const <PaymentUsageItem>[],
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.summary = const PaymentUsageSummary(),
  });

  final List<PaymentUsageItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final PaymentUsageSummary summary;

  bool get hasMore => currentPage < lastPage;
  bool get isEmpty => items.isEmpty;

  factory PaymentUsagePage.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json['data'];
    final List<dynamic> list = rawData is List ? rawData : <dynamic>[];
    final dynamic meta = json['meta'];
    final dynamic rawSummary = json['summary'];

    return PaymentUsagePage(
      items: list.whereType<Map<String, dynamic>>().map(PaymentUsageItem.fromJson).toList(),
      currentPage: meta is Map ? (meta['current_page'] as int? ?? 1) : 1,
      lastPage: meta is Map ? (meta['last_page'] as int? ?? 1) : 1,
      total: meta is Map ? (meta['total'] as int? ?? list.length) : list.length,
      summary: PaymentUsageSummary.fromJson(
        rawSummary is Map<String, dynamic> ? rawSummary : null,
      ),
    );
  }
}

/// Single transaction invoice/history row (`GET /payments/history` and `GET /payments/invoices/{id}`).
class PaymentHistoryItem {
  const PaymentHistoryItem({
    required this.id,
    required this.paymentCode,
    required this.invoiceNumber,
    this.package,
    this.paymentMethod = '',
    this.paymentStatus = '',
    this.gatewayStatus = '',
    this.gatewayReference,
    this.amount = 0,
    this.discountAmount = 0,
    this.payableAmount = 0,
    this.currency = 'PKR',
    this.paidAt,
    this.subscriptionEndsAt,
    this.metadata,
    this.createdAt,
  });

  final int id;
  final String paymentCode;
  final String invoiceNumber;
  final PaymentPlanModel? package;
  final String paymentMethod;
  final String paymentStatus;
  final String gatewayStatus;
  final String? gatewayReference;
  final num amount;
  final num discountAmount;
  final num payableAmount;
  final String currency;
  final DateTime? paidAt;
  final DateTime? subscriptionEndsAt;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  bool get isPaid => paymentStatus.toLowerCase() == 'paid' || gatewayStatus.toLowerCase() == 'paid';

  factory PaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    final dynamic rawPkg = json['package'];
    return PaymentHistoryItem(
      id: _asInt(json['id']),
      paymentCode: json['payment_code'] as String? ?? '',
      invoiceNumber: json['invoice_number'] as String? ?? '',
      package: rawPkg is Map<String, dynamic> ? PaymentPlanModel.fromJson(rawPkg) : null,
      paymentMethod: json['payment_method'] as String? ?? 'N/A',
      paymentStatus: json['payment_status'] as String? ?? 'Pending',
      gatewayStatus: json['gateway_status'] as String? ?? '',
      gatewayReference: json['gateway_reference'] as String?,
      amount: json['amount'] as num? ?? 0,
      discountAmount: json['discount_amount'] as num? ?? 0,
      payableAmount: json['payable_amount'] as num? ?? 0,
      currency: json['currency'] as String? ?? 'PKR',
      paidAt: _asDate(json['paid_at']),
      subscriptionEndsAt: _asDate(json['subscription_ends_at']),
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : null,
      createdAt: _asDate(json['created_at']),
    );
  }
}

/// Paginated response from `GET /payments/history`.
class PaymentHistoryPage {
  const PaymentHistoryPage({
    this.items = const <PaymentHistoryItem>[],
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
  });

  final List<PaymentHistoryItem> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
  bool get isEmpty => items.isEmpty;

  factory PaymentHistoryPage.fromJson(Map<String, dynamic> json) {
    final dynamic rawData = json['data'];
    final List<dynamic> list = rawData is List ? rawData : <dynamic>[];
    final dynamic meta = json['meta'];

    return PaymentHistoryPage(
      items: list.whereType<Map<String, dynamic>>().map(PaymentHistoryItem.fromJson).toList(),
      currentPage: meta is Map ? (meta['current_page'] as int? ?? 1) : 1,
      lastPage: meta is Map ? (meta['last_page'] as int? ?? 1) : 1,
      total: meta is Map ? (meta['total'] as int? ?? list.length) : list.length,
    );
  }
}

/// Response from `POST /payments/coupons/validate`.
class CouponValidationResult {
  const CouponValidationResult({
    required this.isValid,
    this.discountAmount = 0,
    this.finalPrice,
    this.message,
  });

  final bool isValid;
  final num discountAmount;
  final num? finalPrice;
  final String? message;

  factory CouponValidationResult.fromJson(Map<String, dynamic> json, {bool success = true}) {
    return CouponValidationResult(
      isValid: success,
      discountAmount: json['discount_amount'] as num? ?? json['discount'] as num? ?? 0,
      finalPrice: json['final_price'] as num? ?? json['payable_amount'] as num?,
      message: json['message'] as String?,
    );
  }
}

/// Response from `POST /payments/checkout`.
class CheckoutResult {
  const CheckoutResult({
    required this.success,
    this.message,
    this.paymentCode,
    this.invoiceNumber,
    this.paymentStatus,
    this.instructions,
    this.gatewayUrl,
    this.data,
  });

  final bool success;
  final String? message;
  final String? paymentCode;
  final String? invoiceNumber;
  final String? paymentStatus;
  final String? instructions;
  final String? gatewayUrl;
  final Map<String, dynamic>? data;

  factory CheckoutResult.fromJson(Map<String, dynamic> json, {bool success = true, String? message}) {
    final Map<String, dynamic> d = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;
    return CheckoutResult(
      success: success,
      message: message ?? json['message'] as String?,
      paymentCode: d['payment_code'] as String?,
      invoiceNumber: d['invoice_number'] as String?,
      paymentStatus: d['payment_status'] as String? ?? d['status'] as String?,
      instructions: d['instructions'] as String? ?? d['note'] as String?,
      gatewayUrl: d['checkout_url'] as String? ?? d['gateway_url'] as String?,
      data: d,
    );
  }
}

// ---------------------------------------------------------------------------
// Serialization helpers
// ---------------------------------------------------------------------------

int _asInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

bool _asBool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is int) return v == 1;
  if (v is String) {
    final String s = v.trim().toLowerCase();
    if (s == '1' || s == 'true' || s == 'yes') return true;
    if (s == '0' || s == 'false' || s == 'no') return false;
  }
  return fallback;
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}
