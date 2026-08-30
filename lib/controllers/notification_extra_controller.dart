import 'package:get/get.dart';
import '../repositories/notification_extra_repository.dart';
import '../widgets/app_snackbar.dart';

/// Extra notification features: unread count, preferences.
class NotificationExtraController extends GetxController {
  NotificationExtraController(this._repo);

  final NotificationExtraRepository _repo;

  final RxInt unreadCount = 0.obs;
  final RxMap<String, dynamic> preferences = <String, dynamic>{}.obs;

  Future<void> fetchUnreadCount() async {
    try {
      unreadCount.value = await _repo.fetchUnreadCount();
    } catch (_) {}
  }

  Future<void> fetchPreferences() async {
    try {
      preferences.assignAll(await _repo.fetchPreferences());
    } catch (_) {}
  }

  Future<void> updatePreferences(Map<String, dynamic> body) async {
    try {
      final Map<String, dynamic> updated = await _repo.updatePreferences(body);
      preferences.assignAll(updated);
      AppSnackbar.success('Preferences updated.');
    } catch (e) {
      AppSnackbar.error('Failed to update preferences.');
    }
  }
}
