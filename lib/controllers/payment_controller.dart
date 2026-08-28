import 'package:get/get.dart';

import '../core/api/api_response.dart';
import '../exceptions/app_exceptions.dart';
import '../core/storage/secure_storage_service.dart';
import '../models/payment_model.dart';
import '../repositories/payment_repository.dart';
import '../widgets/app_snackbar.dart';

class PaymentController extends GetxController {
  PaymentController(this._repo);

  final PaymentRepository _repo;

  // ---- Observable State ----------------------------------------------------
  final Rx<ApiState<List<PaymentPlanModel>>> plansState =
      const ApiState<List<PaymentPlanModel>>.initial().obs;

  final Rx<ApiState<CurrentPackageData>> currentPackageState =
      const ApiState<CurrentPackageData>.initial().obs;

  final Rx<ApiState<PaymentUsagePage>> usageState =
      const ApiState<PaymentUsagePage>.initial().obs;

  final Rx<ApiState<PaymentHistoryPage>> historyState =
      const ApiState<PaymentHistoryPage>.initial().obs;

  // Selected plan for checkout modal
  final Rxn<PaymentPlanModel> selectedPlan = Rxn<PaymentPlanModel>();

  // Checkout form observables
  final RxString selectedGateway = 'stripe'.obs; // 'stripe' | 'easypaisa' | 'jazzcash'
  final RxString couponCode = ''.obs;
  final Rxn<CouponValidationResult> couponResult = Rxn<CouponValidationResult>();
  final RxBool isValidatingCoupon = false.obs;
  final RxBool isCheckingOut = false.obs;

  // Pagination states
  final RxBool isLoadingMoreUsage = false.obs;
  final RxBool isLoadingMoreHistory = false.obs;
  int _usageCurrentPage = 1;
  int _usageLastPage = 1;
  int _historyCurrentPage = 1;
  int _historyLastPage = 1;

  bool get _hasToken =>
      Get.isRegistered<SecureStorageService>() &&
      Get.find<SecureStorageService>().hasToken;

  @override
  void onInit() {
    super.onInit();
    if (_hasToken) {
      loadCurrentPackage();
      loadPlans();
    }
  }

  void reset() {
    plansState.value = const ApiState<List<PaymentPlanModel>>.initial();
    currentPackageState.value = const ApiState<CurrentPackageData>.initial();
    usageState.value = const ApiState<PaymentUsagePage>.initial();
    historyState.value = const ApiState<PaymentHistoryPage>.initial();
    selectedPlan.value = null;
    couponResult.value = null;
  }

  // ---- 1. Membership Plans -------------------------------------------------

  /// Fetches available subscription plans (`GET /payments/plans`).
  Future<void> loadPlans({bool silent = false}) async {
    if (!_hasToken) return;

    if (!silent) {
      plansState.value = const ApiState<List<PaymentPlanModel>>.loading();
    }
    try {
      final List<PaymentPlanModel> list = await _repo.fetchPlans();
      plansState.value = list.isEmpty
          ? const ApiState<List<PaymentPlanModel>>.empty(message: 'No subscription plans available.')
          : ApiState<List<PaymentPlanModel>>.success(list);
    } on AppException catch (e) {
      if (!silent) plansState.value = ApiState<List<PaymentPlanModel>>.fromException(e);
    } catch (e) {
      if (!silent) plansState.value = ApiState<List<PaymentPlanModel>>.serverError(e.toString());
    }
  }

  // ---- 2. Current Package --------------------------------------------------

  /// Fetches active package and coin balance (`GET /payments/current`).
  Future<void> loadCurrentPackage({bool silent = false}) async {
    if (!_hasToken) return;

    if (!silent) {
      currentPackageState.value = const ApiState<CurrentPackageData>.loading();
    }
    try {
      final CurrentPackageData data = await _repo.fetchCurrentPackage();

      currentPackageState.value = ApiState<CurrentPackageData>.success(data);
    } on AppException catch (e) {
      if (!silent) currentPackageState.value = ApiState<CurrentPackageData>.fromException(e);
    } catch (e) {
      if (!silent) currentPackageState.value = ApiState<CurrentPackageData>.serverError(e.toString());
    }
  }

  // ---- 3. Feature & Coin Usage ---------------------------------------------

  /// Fetches usage breakdown list (`GET /payments/usage`).
  Future<void> loadUsage({bool silent = false, String? feature}) async {
    if (!silent) {
      usageState.value = const ApiState<PaymentUsagePage>.loading();
    }
    try {
      final PaymentUsagePage page = await _repo.fetchUsage(page: 1, feature: feature);
      _usageCurrentPage = page.currentPage;
      _usageLastPage = page.lastPage;
      usageState.value = page.isEmpty
          ? const ApiState<PaymentUsagePage>.empty(message: 'No feature usage records found.')
          : ApiState<PaymentUsagePage>.success(page);
    } on AppException catch (e) {
      if (!silent) usageState.value = ApiState<PaymentUsagePage>.fromException(e);
    } catch (e) {
      if (!silent) usageState.value = ApiState<PaymentUsagePage>.serverError(e.toString());
    }
  }

  /// Loads next page of usage records.
  Future<void> loadMoreUsage() async {
    if (isLoadingMoreUsage.value || _usageCurrentPage >= _usageLastPage) return;
    isLoadingMoreUsage.value = true;
    try {
      final int nextPage = _usageCurrentPage + 1;
      final PaymentUsagePage nextPageData = await _repo.fetchUsage(page: nextPage);
      _usageCurrentPage = nextPageData.currentPage;
      _usageLastPage = nextPageData.lastPage;

      final PaymentUsagePage current = usageState.value.data!;
      final List<PaymentUsageItem> merged = <PaymentUsageItem>[
        ...current.items,
        ...nextPageData.items,
      ];
      usageState.value = ApiState<PaymentUsagePage>.success(
        PaymentUsagePage(
          items: merged,
          currentPage: _usageCurrentPage,
          lastPage: _usageLastPage,
          total: nextPageData.total,
          summary: current.summary,
        ),
      );
    } catch (_) {} finally {
      isLoadingMoreUsage.value = false;
    }
  }

  // ---- 4. Payment History & Invoices ----------------------------------------

  /// Fetches payment history list (`GET /payments/history`).
  Future<void> loadHistory({bool silent = false}) async {
    if (!silent) {
      historyState.value = const ApiState<PaymentHistoryPage>.loading();
    }
    try {
      final PaymentHistoryPage page = await _repo.fetchHistory(page: 1);
      _historyCurrentPage = page.currentPage;
      _historyLastPage = page.lastPage;
      historyState.value = page.isEmpty
          ? const ApiState<PaymentHistoryPage>.empty(message: 'No payment transactions recorded yet.')
          : ApiState<PaymentHistoryPage>.success(page);
    } on AppException catch (e) {
      if (!silent) historyState.value = ApiState<PaymentHistoryPage>.fromException(e);
    } catch (e) {
      if (!silent) historyState.value = ApiState<PaymentHistoryPage>.serverError(e.toString());
    }
  }

  /// Loads next page of payment history transactions.
  Future<void> loadMoreHistory() async {
    if (isLoadingMoreHistory.value || _historyCurrentPage >= _historyLastPage) return;
    isLoadingMoreHistory.value = true;
    try {
      final int nextPage = _historyCurrentPage + 1;
      final PaymentHistoryPage nextPageData = await _repo.fetchHistory(page: nextPage);
      _historyCurrentPage = nextPageData.currentPage;
      _historyLastPage = nextPageData.lastPage;

      final PaymentHistoryPage current = historyState.value.data!;
      final List<PaymentHistoryItem> merged = <PaymentHistoryItem>[
        ...current.items,
        ...nextPageData.items,
      ];
      historyState.value = ApiState<PaymentHistoryPage>.success(
        PaymentHistoryPage(
          items: merged,
          currentPage: _historyCurrentPage,
          lastPage: _historyLastPage,
          total: nextPageData.total,
        ),
      );
    } catch (_) {} finally {
      isLoadingMoreHistory.value = false;
    }
  }

  /// Fetches single invoice details (`GET /payments/invoices/{id}`).
  Future<PaymentHistoryItem?> fetchInvoice(int paymentId) async {
    try {
      return await _repo.fetchInvoice(paymentId);
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
      return null;
    } catch (e) {
      AppSnackbar.error('Failed to load invoice: $e');
      return null;
    }
  }

  // ---- 5. Coupon & Checkout ------------------------------------------------

  /// Validates promo coupon for the selected package (`POST /payments/coupons/validate`).
  Future<void> validateCoupon(int packageId, String code) async {
    if (code.trim().isEmpty) return;
    isValidatingCoupon.value = true;
    couponResult.value = null;
    try {
      final CouponValidationResult result = await _repo.validateCoupon(
        packageId: packageId,
        code: code,
      );
      couponResult.value = result;
      AppSnackbar.success('Coupon applied successfully!');
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
    } catch (e) {
      AppSnackbar.error('Coupon is invalid or expired.');
    } finally {
      isValidatingCoupon.value = false;
    }
  }

  void clearCoupon() {
    couponCode.value = '';
    couponResult.value = null;
  }

  /// Initiates payment checkout (`POST /payments/checkout`).
  Future<CheckoutResult?> checkout({
    required int packageId,
    String? easypaisaPhone,
    String? jazzcashPhone,
  }) async {
    isCheckingOut.value = true;
    try {
      final CheckoutResult result = await _repo.checkout(
        packageId: packageId,
        gateway: selectedGateway.value,
        couponCode: couponResult.value?.isValid == true ? couponCode.value : null,
        easypaisaPhone: easypaisaPhone,
        jazzcashPhone: jazzcashPhone,
      );

      // Refresh current package and history
      loadCurrentPackage(silent: true);
      loadHistory(silent: true);

      return result;
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
      return null;
    } catch (e) {
      AppSnackbar.error('Checkout failed. Please try again.');
      return null;
    } finally {
      isCheckingOut.value = false;
    }
  }
}
