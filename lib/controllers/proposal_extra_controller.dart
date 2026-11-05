import 'package:get/get.dart';
import '../exceptions/app_exceptions.dart';
import '../features/payments/views/membership_plans_view.dart';
import '../models/search_filter_profile_model.dart';
import '../repositories/proposal_extra_repository.dart';
import '../widgets/app_snackbar.dart';

/// Favourites, ignored, notes, timeline, meetings for proposals.
class ProposalExtraController extends GetxController {
  ProposalExtraController(this._repo);

  final ProposalExtraRepository _repo;

  final RxSet<int> favouriteUserIds = <int>{}.obs;
  final RxBool busy = false.obs;

  // ---- Favourites ------------------------------------------------------------

  Future<void> loadFavourites() async {
    try {
      final List<Map<String, dynamic>> data = await _repo.fetchFavourites();
      favouriteUserIds.assignAll(data.map((e) => (e['id'] as int?) ?? 0).where((int id) => id > 0));
    } catch (_) {}
  }

  bool isFavourite(int userId) => favouriteUserIds.contains(userId);

  Future<void> toggleFavourite(int userId) async {
    if (busy.value) return;
    busy.value = true;
    try {
      if (favouriteUserIds.contains(userId)) {
        await _repo.removeFavourite(userId);
        favouriteUserIds.remove(userId);
      } else {
        await _repo.addFavourite(userId: userId);
        favouriteUserIds.add(userId);
        AppSnackbar.success('Added to favourites.');
      }
    } on AppException catch (e) {
      // Favouriting now costs a coin: a 402 means the wallet is empty, so
      // send the member to the packages screen instead of a dead error.
      if (e.statusCode == 402 || (e is ApiException && e.code == 'insufficient_coins')) {
        AppSnackbar.error('You need a coin to favourite this profile.');
        Get.to<void>(() => const MembershipPlansView());
      } else {
        AppSnackbar.error(e.message);
      }
    } catch (e) {
      AppSnackbar.error('Failed to update favourite.');
    } finally {
      busy.value = false;
    }
  }

  // ---- Ignored ---------------------------------------------------------------

  /// The member's ignored profiles (Discover 'Ignore Profile'), for the
  /// separate Ignored list screen with its Restore action.
  final RxList<SearchProfileModel> ignoredProfiles = <SearchProfileModel>[].obs;
  final RxBool ignoredLoading = false.obs;

  Future<void> loadIgnored() async {
    ignoredLoading.value = true;
    try {
      final List<SearchProfileModel> data = await _repo.fetchIgnored();
      ignoredProfiles.assignAll(data);
    } catch (_) {
      // Keep whatever is showing; the screen has its own retry affordance.
    } finally {
      ignoredLoading.value = false;
    }
  }

  Future<void> ignoreUser(int userId) async {
    try {
      await _repo.ignore(userId: userId);
      AppSnackbar.success('Profile ignored.');
    } catch (e) {
      AppSnackbar.error('Failed to ignore profile.');
    }
  }

  /// Removes the profile from the server's ignored list and, on success, from
  /// the local list so the row disappears immediately.
  Future<void> unignoreUser(int userId) async {
    try {
      await _repo.removeIgnore(userId);
      ignoredProfiles.removeWhere((SearchProfileModel p) => p.id == userId);
      AppSnackbar.success('Profile restored to Discover.');
    } catch (e) {
      AppSnackbar.error('Failed to restore profile.');
    }
  }

  // ---- Notes -----------------------------------------------------------------

  Future<void> addProposalNote(int proposalId, String note) async {
    try {
      await _repo.addNote(proposalId: proposalId, note: note);
      AppSnackbar.success('Note added.');
    } catch (e) {
      AppSnackbar.error('Failed to add note.');
    }
  }

  // ---- Timeline ---------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchTimeline(int proposalId) async {
    try {
      return await _repo.fetchTimeline(proposalId);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  // ---- Meetings ---------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchMeetings(int proposalId) async {
    try {
      return await _repo.fetchMeetings(proposalId);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<bool> scheduleMeeting(int proposalId, Map<String, dynamic> data) async {
    try {
      await _repo.scheduleMeeting(proposalId: proposalId, data: data);
      AppSnackbar.success('Meeting scheduled.');
      return true;
    } catch (e) {
      AppSnackbar.error('Failed to schedule meeting.');
      return false;
    }
  }

  Future<void> updateMeeting(int meetingId, Map<String, dynamic> data) async {
    try {
      await _repo.updateMeeting(meetingId: meetingId, data: data);
      AppSnackbar.success('Meeting updated.');
    } catch (e) {
      AppSnackbar.error('Failed to update meeting.');
    }
  }

  Future<void> meetingFeedback(int meetingId, Map<String, dynamic> data) async {
    try {
      await _repo.meetingFeedback(meetingId: meetingId, data: data);
      AppSnackbar.success('Feedback submitted.');
    } catch (e) {
      AppSnackbar.error('Failed to submit feedback.');
    }
  }

  // ---- Relationship Status ----------------------------------------------------

  Future<void> updateRelationshipStatus({
    required int partnerUserId,
    required String status,
    int? proposalId,
    String? notes,
  }) async {
    try {
      await _repo.updateRelationshipStatus(
        partnerUserId: partnerUserId,
        status: status,
        proposalId: proposalId,
        notes: notes,
      );
      AppSnackbar.success('Relationship status submitted for review.');
    } catch (e) {
      AppSnackbar.error('Failed to update status.');
    }
  }
}
