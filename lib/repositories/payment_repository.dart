import '../constants/api_endpoints.dart';
import '../core/api/api_client.dart';
import '../models/payment_model.dart';

/// All REST API calls for Membership Plans, Subscriptions, Invoices, Usage, and Checkout.
class PaymentRepository {
  PaymentRepository(this._client);

  final ApiClient _client;

  /// `GET /payments/plans` — List of available membership plans.
  Future<List<PaymentPlanModel>> fetchPlans() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.paymentPlans);
    final List<dynamic> raw = res.dataList;
    return raw.whereType<Map<String, dynamic>>().map(PaymentPlanModel.fromJson).toList();
  }

  /// `GET /payments/current` — Current active package details and coin balance.
  Future<CurrentPackageData> fetchCurrentPackage() async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.paymentCurrent);
    return CurrentPackageData.fromJson(res.dataMap);
  }

  /// `GET /payments/packages/{packageId}` — Details for a specific package.
  Future<PaymentPlanModel> fetchPackageDetails(int packageId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.paymentPackage(packageId));
    return PaymentPlanModel.fromJson(res.dataMap);
  }

  /// `GET /payments/usage` — Paginated feature usage breakdown.
  Future<PaymentUsagePage> fetchUsage({int page = 1, int perPage = 20, String? feature}) async {
    final Map<String, dynamic> query = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (feature != null && feature.isNotEmpty) {
      query['feature'] = feature;
    }
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.paymentUsage,
      query: query,
    );
    return PaymentUsagePage.fromJson(res.raw);
  }

  /// `GET /payments/history` — Paginated payment history.
  Future<PaymentHistoryPage> fetchHistory({int page = 1, int perPage = 20}) async {
    final ApiEnvelope res = await _client.get(
      ApiEndpoints.paymentHistory,
      query: <String, dynamic>{
        'page': page,
        'per_page': perPage,
      },
    );
    return PaymentHistoryPage.fromJson(res.raw);
  }

  /// `GET /payments/invoices/{paymentId}` — Detailed invoice for a payment.
  Future<PaymentHistoryItem> fetchInvoice(int paymentId) async {
    final ApiEnvelope res = await _client.get(ApiEndpoints.paymentInvoice(paymentId));
    return PaymentHistoryItem.fromJson(res.dataMap);
  }

  /// `POST /payments/coupons/validate` — Validate a discount coupon.
  Future<CouponValidationResult> validateCoupon({
    required int packageId,
    required String code,
  }) async {
    final ApiEnvelope res = await _client.post(
      ApiEndpoints.paymentValidateCoupon,
      body: <String, dynamic>{
        'package_id': packageId,
        'code': code.trim(),
      },
    );
    return CouponValidationResult.fromJson(res.dataMap, success: res.success);
  }

  /// `POST /payments/checkout` — Initiate subscription payment checkout.
  Future<CheckoutResult> checkout({
    required int packageId,
    required String gateway, // 'stripe' | 'easypaisa' | 'jazzcash'
    String currency = 'PKR',
    String? couponCode,
    String? easypaisaPhone,
    String? jazzcashPhone,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'package_id': packageId,
      'gateway': gateway.toLowerCase(),
      'currency': currency,
    };
    if (couponCode != null && couponCode.trim().isNotEmpty) {
      body['coupon_code'] = couponCode.trim();
    }
    if (easypaisaPhone != null && easypaisaPhone.trim().isNotEmpty) {
      body['easypaisa_phone'] = easypaisaPhone.trim();
    }
    if (jazzcashPhone != null && jazzcashPhone.trim().isNotEmpty) {
      body['jazzcash_phone'] = jazzcashPhone.trim();
    }

    final ApiEnvelope res = await _client.post(
      ApiEndpoints.paymentCheckout,
      body: body,
    );
    return CheckoutResult.fromJson(res.raw, success: res.success, message: res.message);
  }
}
