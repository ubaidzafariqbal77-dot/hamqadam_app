import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/api/api_response.dart';
import '../features/discover/widgets/public_profile_detail_sheet.dart';
import '../models/profile_view_model.dart';
import '../repositories/profile_view_repository.dart';

/// GetX Controller managing profile views (received, sent/viewed by me, and allowance balance).
class ProfileViewController extends GetxController {
  ProfileViewController(this._repo);

  final ProfileViewRepository _repo;

  // --------------------------------------------------------------------------
  // States
  // --------------------------------------------------------------------------

  final Rx<ApiState<List<ProfileViewItem>>> receivedState =
      const ApiState<List<ProfileViewItem>>.initial().obs;

  final Rx<ApiState<List<ProfileViewItem>>> myViewsState =
      const ApiState<List<ProfileViewItem>>.initial().obs;

  final Rxn<ProfileViewSummary> summary = Rxn<ProfileViewSummary>();

  final RxInt activeTabIndex = 0.obs; // 0: Received (Who Viewed Me), 1: Viewed By Me

  // Pagination for Received Views
  int _receivedPage = 1;
  final RxBool hasMoreReceived = false.obs;
  final RxBool isLoadingMoreReceived = false.obs;
  final List<ProfileViewItem> _receivedList = <ProfileViewItem>[];

  // Pagination for My Views
  int _myViewsPage = 1;
  final RxBool hasMoreMyViews = false.obs;
  final RxBool isLoadingMoreMyViews = false.obs;
  final List<ProfileViewItem> _myViewsList = <ProfileViewItem>[];

  // Total counts for badges
  final RxInt totalReceivedCount = 0.obs;
  final RxInt totalMyViewsCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  /// Initial or full refresh.
  Future<void> loadAll() async {
    await Future.wait<void>(<Future<void>>[
      loadReceived(refresh: true),
      loadMyViews(refresh: true),
      loadBalance(),
    ]);
  }

  // --------------------------------------------------------------------------
  // Received Views (Who Viewed Me)
  // --------------------------------------------------------------------------

  Future<void> loadReceived({bool refresh = false}) async {
    if (refresh) {
      _receivedPage = 1;
      _receivedList.clear();
      receivedState.value = const ApiState<List<ProfileViewItem>>.loading();
    }

    try {
      final ProfileViewsPage page = await _repo.fetchReceivedViews(page: _receivedPage);
      if (refresh) _receivedList.clear();
      _receivedList.addAll(page.items);

      if (page.summary != null) {
        summary.value = page.summary;
      }
      totalReceivedCount.value = page.total;
      hasMoreReceived.value = page.hasMore;

      receivedState.value = _receivedList.isEmpty
          ? const ApiState<List<ProfileViewItem>>.empty(message: 'No one has viewed your profile yet.')
          : ApiState<List<ProfileViewItem>>.success(List<ProfileViewItem>.from(_receivedList));
    } catch (e) {
      if (refresh || _receivedList.isEmpty) {
        receivedState.value = ApiState<List<ProfileViewItem>>.serverError(e.toString());
      }
    }
  }

  Future<void> loadMoreReceived() async {
    if (isLoadingMoreReceived.value || !hasMoreReceived.value) return;
    isLoadingMoreReceived.value = true;
    try {
      final int nextPage = _receivedPage + 1;
      final ProfileViewsPage page = await _repo.fetchReceivedViews(page: nextPage);
      _receivedPage = nextPage;
      _receivedList.addAll(page.items);
      hasMoreReceived.value = page.hasMore;
      receivedState.value = ApiState<List<ProfileViewItem>>.success(
        List<ProfileViewItem>.from(_receivedList),
      );
    } catch (_) {} finally {
      isLoadingMoreReceived.value = false;
    }
  }

  // --------------------------------------------------------------------------
  // My Views (Profiles I Viewed)
  // --------------------------------------------------------------------------

  Future<void> loadMyViews({bool refresh = false}) async {
    if (refresh) {
      _myViewsPage = 1;
      _myViewsList.clear();
      myViewsState.value = const ApiState<List<ProfileViewItem>>.loading();
    }

    try {
      final ProfileViewsPage page = await _repo.fetchMyViews(page: _myViewsPage);
      if (refresh) _myViewsList.clear();
      _myViewsList.addAll(page.items);

      if (page.summary != null) {
        summary.value = page.summary;
      }
      totalMyViewsCount.value = page.total;
      hasMoreMyViews.value = page.hasMore;

      myViewsState.value = _myViewsList.isEmpty
          ? const ApiState<List<ProfileViewItem>>.empty(message: 'You have not viewed any profiles yet.')
          : ApiState<List<ProfileViewItem>>.success(List<ProfileViewItem>.from(_myViewsList));
    } catch (e) {
      if (refresh || _myViewsList.isEmpty) {
        myViewsState.value = ApiState<List<ProfileViewItem>>.serverError(e.toString());
      }
    }
  }

  Future<void> loadMoreMyViews() async {
    if (isLoadingMoreMyViews.value || !hasMoreMyViews.value) return;
    isLoadingMoreMyViews.value = true;
    try {
      final int nextPage = _myViewsPage + 1;
      final ProfileViewsPage page = await _repo.fetchMyViews(page: nextPage);
      _myViewsPage = nextPage;
      _myViewsList.addAll(page.items);
      hasMoreMyViews.value = page.hasMore;
      myViewsState.value = ApiState<List<ProfileViewItem>>.success(
        List<ProfileViewItem>.from(_myViewsList),
      );
    } catch (_) {} finally {
      isLoadingMoreMyViews.value = false;
    }
  }

  // --------------------------------------------------------------------------
  // Balance
  // --------------------------------------------------------------------------

  Future<void> loadBalance() async {
    try {
      final ProfileViewSummary b = await _repo.fetchBalance();
      summary.value = b;
    } catch (_) {}
  }

  // --------------------------------------------------------------------------
  // Consume Allowance Action
  // --------------------------------------------------------------------------

  /// Consumes one profile-view allowance and opens the public profile sheet.
  Future<void> openProfileWithView(BuildContext context, int profileId) async {
    PublicProfileDetailSheet.show(context, profileId: profileId);
    // Refresh balance and viewed lists in background
    loadAll();
  }
}
