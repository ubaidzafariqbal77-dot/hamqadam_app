import 'package:get/get.dart';

import '../core/api/api_client.dart';
import '../core/utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';
import '../repositories/horoscope_repository.dart';
import '../widgets/app_snackbar.dart';

/// Manages horoscope form state, dropdown data, save, and matched profiles.
class HoroscopeController extends GetxController {
  HoroscopeController(this._repo);

  final HoroscopeRepository _repo;

  // ---- Dropdown data ----
  final RxBool dropdownsLoading = false.obs;
  final RxList<Map<String, String>> sunSigns = <Map<String, String>>[].obs;
  final RxList<Map<String, String>> moonSigns = <Map<String, String>>[].obs;
  final RxList<Map<String, String>> nakshatras = <Map<String, String>>[].obs;
  final RxList<Map<String, String>> ganaList = <Map<String, String>>[].obs;
  final RxList<Map<String, String>> nadiList = <Map<String, String>>[].obs;
  final RxList<Map<String, String>> manglikList = <Map<String, String>>[].obs;

  // ---- Form fields ----
  final RxString timeOfBirth = ''.obs;
  final RxString cityOfBirth = ''.obs;
  final RxString sunSign = ''.obs;
  final RxString moonSign = ''.obs;
  final RxString nakshatra = ''.obs;
  final RxString gana = ''.obs;
  final RxString nadi = ''.obs;
  final RxString manglik = ''.obs;

  // ---- State ----
  final RxBool saving = false.obs;
  final RxBool loadingMatches = false.obs;
  final RxBool horoscopeFilled = false.obs;
  final RxInt matchedCount = 0.obs;
  final RxList<Map<String, dynamic>> matchedProfiles = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadDropdowns();
  }

  /// Fetches dropdown data from the server.
  Future<void> loadDropdowns() async {
    dropdownsLoading.value = true;
    try {
      final ApiEnvelope res = await _repo.getDropdowns();
      if (!res.success) return;
      final Map<String, dynamic> dd = res.dataMap['horoscope_dropdowns'] ?? {};
      _parseList(sunSigns, dd['sun_signs']);
      _parseList(moonSigns, dd['moon_signs']);
      _parseList(nakshatras, dd['nakshatras']);
      _parseList(ganaList, dd['gana']);
      _parseList(nadiList, dd['nadi']);
      _parseList(manglikList, dd['manglik']);
    } on AppException catch (e) {
      AppLogger.w('Horoscope dropdowns failed: $e');
    } catch (e) {
      AppLogger.w('Horoscope dropdowns failed: $e');
    } finally {
      dropdownsLoading.value = false;
    }
  }

  void _parseList(RxList<Map<String, String>> target, dynamic raw) {
    target.clear();
    if (raw is List) {
      for (final dynamic item in raw) {
        if (item is Map<String, dynamic>) {
          target.add(<String, String>{
            'value': (item['value'] ?? '').toString(),
            'label': (item['label'] ?? item['value'] ?? '').toString(),
          });
        } else if (item is String) {
          target.add(<String, String>{'value': item, 'label': item});
        }
      }
    }
  }

  /// Saves horoscope data to the server.
  Future<bool> save() async {
    if (timeOfBirth.value.trim().isEmpty) {
      AppSnackbar.error('Time of birth is required');
      return false;
    }
    if (cityOfBirth.value.trim().isEmpty) {
      AppSnackbar.error('City of birth is required');
      return false;
    }

    saving.value = true;
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'time_of_birth': timeOfBirth.value.trim(),
        'city_of_birth': cityOfBirth.value.trim(),
        if (sunSign.value.isNotEmpty) 'sun_sign': sunSign.value,
        if (moonSign.value.isNotEmpty) 'moon_sign': moonSign.value,
        if (nakshatra.value.isNotEmpty) 'nakshatra': nakshatra.value,
        if (gana.value.isNotEmpty) 'gana': gana.value,
        if (nadi.value.isNotEmpty) 'nadi': nadi.value,
        if (manglik.value.isNotEmpty) 'manglik': manglik.value,
      };
      final ApiEnvelope res = await _repo.update(payload);
      if (res.success) {
        horoscopeFilled.value = true;
        AppSnackbar.success(res.message.isEmpty ? 'Horoscope updated successfully!' : res.message);
        return true;
      } else {
        AppSnackbar.error(res.message.isEmpty ? 'Failed to update horoscope.' : res.message);
        return false;
      }
    } on AppException catch (e) {
      AppSnackbar.error(e.message);
      return false;
    } catch (e) {
      AppSnackbar.error('Something went wrong. Please try again.');
      return false;
    } finally {
      saving.value = false;
    }
  }

  /// Loads horoscope-matched profiles.
  Future<void> loadMatchedProfiles() async {
    loadingMatches.value = true;
    try {
      final ApiEnvelope res = await _repo.getMatchedProfiles();
      if (res.success) {
        horoscopeFilled.value = res.dataMap['horoscope_filled'] ?? false;
        matchedCount.value = res.dataMap['matched_count'] ?? 0;
        final List<dynamic> profiles = res.dataMap['matched_profiles'] ?? [];
        matchedProfiles.assignAll(
          profiles.map<Map<String, dynamic>>((dynamic e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    } on AppException catch (e) {
      AppLogger.w('Horoscope matched profiles failed: $e');
    } catch (e) {
      AppLogger.w('Horoscope matched profiles failed: $e');
    } finally {
      loadingMatches.value = false;
    }
  }

  /// Helper to find the label for a value from a dropdown list.
  String findLabel(List<Map<String, String>> items, String value) {
    for (final Map<String, String> item in items) {
      if (item['value'] == value) return item['label'] ?? value;
    }
    return value;
  }
}
