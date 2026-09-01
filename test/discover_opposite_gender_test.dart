// Discover shows the OTHER gender only: a male member sees women, a female
// member sees men.
//
// It was already trying to — `SearchProfilesController` pre-filled a gender
// filter — but it read the member's gender off `AuthController.user.gender`,
// and gender does not live there. The captured profile
// (`dev_stubs/api_samples/profile.json`) carries it as `member.gender`, so the
// lookup came back null, the filter was never applied and Discover listed
// everybody. On top of that the filter sheet offered an "All / Male / Female"
// selector and the active-filter chip row offered a × on the gender, either of
// which put a member's own gender back on screen.
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hamqadam/controllers/auth_controller.dart';
import 'package:hamqadam/controllers/lookup_controller.dart';
import 'package:hamqadam/controllers/profile_controller.dart';
import 'package:hamqadam/controllers/search_profiles_controller.dart';
import 'package:hamqadam/core/api/api_client.dart';
import 'package:hamqadam/core/network/network_info.dart';
import 'package:hamqadam/core/storage/current_user_service.dart';
import 'package:hamqadam/core/storage/profile_completion_service.dart';
import 'package:hamqadam/core/storage/secure_storage_service.dart';
import 'package:hamqadam/models/profile_model.dart';
import 'package:hamqadam/models/search_filter_profile_model.dart';
import 'package:hamqadam/models/user_model.dart';
import 'package:hamqadam/repositories/auth_repository.dart';
import 'package:hamqadam/repositories/lookup_repository.dart';
import 'package:hamqadam/repositories/profile_repository.dart';
import 'package:hamqadam/repositories/search_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';
import 'dart:io';

ApiClient _client() => ApiClient(
      storage: SecureStorageService(),
      networkInfo: NetworkInfo(),
    );

/// Records the filter every search was made with and answers with [profiles].
class _FakeSearchRepository extends SearchRepository {
  _FakeSearchRepository(this.profiles) : super(_client());

  final List<SearchProfileModel> profiles;
  final List<SearchFilterModel> calls = <SearchFilterModel>[];

  SearchFilterModel get lastFilter => calls.last;

  @override
  Future<SearchProfilesPage> fetchProfiles({
    required SearchFilterModel filter,
    int page = 1,
    int perPage = 20,
  }) async {
    calls.add(filter);
    return SearchProfilesPage(
      profiles: profiles,
      currentPage: page,
      lastPage: 2,
      perPage: perPage,
      total: profiles.length,
    );
  }
}

/// Serves the captured profile with its gender swapped as the test needs.
class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(this.gender) : super(_client());

  /// null models a profile that never says what gender the member is.
  final String? gender;

  @override
  Future<ProfileModel> fetchProfile() async {
    final Map<String, dynamic> body = jsonDecode(
      File('dev_stubs/api_samples/profile.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final Map<String, dynamic> data = body['data'] as Map<String, dynamic>;
    (data['member'] as Map<String, dynamic>)['gender'] = gender;
    return ProfileModel.fromJson(data);
  }
}

SearchProfileModel _profile(int id, String? gender) =>
    SearchProfileModel(id: id, name: 'Member $id', gender: gender);

Future<SearchProfilesController> _boot({
  required String? myGender,
  required List<SearchProfileModel> results,
  bool profileRegistered = true,
}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final _FakeSearchRepository search = _FakeSearchRepository(results);

  Get.put<SearchRepository>(search);
  Get.put<LookupController>(LookupController(LookupRepository(_client())));
  Get.put<AuthController>(AuthController(
    authRepository: AuthRepository(_client()),
    storage: SecureStorageService(),
    currentUser: CurrentUserService(prefs),
  ));
  if (profileRegistered) {
    Get.put<ProfileController>(ProfileController(
      _FakeProfileRepository(myGender),
      Get.find<LookupController>(),
      ProfileCompletionService(prefs),
    ));
  }

  final SearchProfilesController controller = SearchProfilesController(
    repository: search,
    lookupController: Get.find<LookupController>(),
  );
  Get.put<SearchProfilesController>(controller);
  // Let ProfileController's fetch settle and the queued reload run.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return controller;
}

_FakeSearchRepository get _search => Get.find<SearchRepository>() as _FakeSearchRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('the search asks for the opposite gender', () {
    test('a male member searches for women', () async {
      await _boot(myGender: '1', results: <SearchProfileModel>[]);
      expect(_search.lastFilter.gender, '2');
    });

    test('a female member searches for men', () async {
      await _boot(myGender: '2', results: <SearchProfileModel>[]);
      expect(_search.lastFilter.gender, '1');
    });

    test('the gender rides along on the query the API receives', () async {
      await _boot(myGender: '1', results: <SearchProfileModel>[]);
      expect(_search.lastFilter.toQueryParams()['gender'], '2');
    });

    test('an unknown gender searches unfiltered rather than showing nothing',
        () async {
      await _boot(myGender: null, results: <SearchProfileModel>[]);
      expect(_search.lastFilter.gender, isNull);
    });
  });

  group('the rule cannot be filtered away', () {
    test('applying a filter that names the own gender is overridden', () async {
      final SearchProfilesController c =
          await _boot(myGender: '1', results: <SearchProfileModel>[]);

      // What the removed "Male" chip in the filter sheet used to send.
      c.applyFilter(const SearchFilterModel(gender: '1'));
      await Future<void>.delayed(Duration.zero);

      expect(c.filter.value.gender, '2');
      expect(_search.lastFilter.gender, '2');
    });

    test('clearing the gender filter is overridden', () async {
      final SearchProfilesController c =
          await _boot(myGender: '2', results: <SearchProfileModel>[]);

      // What the removed × on the gender chip used to send.
      c.applyFilter(c.filter.value.copyWith(clearGender: true));
      await Future<void>.delayed(Duration.zero);

      expect(c.filter.value.gender, '1');
      expect(_search.lastFilter.gender, '1');
    });

    test('resetting the filters keeps it', () async {
      final SearchProfilesController c =
          await _boot(myGender: '1', results: <SearchProfileModel>[]);

      c.resetFilter();
      await Future<void>.delayed(Duration.zero);

      expect(c.filter.value.gender, '2');
      expect(_search.lastFilter.gender, '2');
    });

    test('the draft handed to the filter sheet already carries it', () async {
      final SearchProfilesController c =
          await _boot(myGender: '1', results: <SearchProfileModel>[]);

      c.filter.value = const SearchFilterModel();
      c.prepareDraftFilter();

      expect(c.draftFilter.value.gender, '2');
    });

    test('paging keeps it', () async {
      final SearchProfilesController c = await _boot(
        myGender: '1',
        results: <SearchProfileModel>[_profile(1, '2')],
      );

      await c.loadMore();

      expect(_search.calls.last.gender, '2');
      expect(_search.calls.last, isNot(same(_search.calls.first)));
    });
  });

  group('results are screened even if the backend ignores the filter', () {
    test('same-gender profiles are dropped from the grid', () async {
      final SearchProfilesController c = await _boot(
        myGender: '1',
        results: <SearchProfileModel>[
          _profile(1, '2'),
          _profile(2, '1'), // the member's own gender — must not be shown
          _profile(3, '2'),
        ],
      );

      expect(c.profiles.length, 3);
      expect(c.visibleProfiles.map((SearchProfileModel p) => p.id), <int>[1, 3]);
    });

    test('a profile with no gender is kept rather than guessed at', () async {
      final SearchProfilesController c = await _boot(
        myGender: '1',
        results: <SearchProfileModel>[_profile(1, '2'), _profile(2, null)],
      );

      expect(c.visibleProfiles.map((SearchProfileModel p) => p.id), <int>[1, 2]);
    });

    test('nothing is screened while the own gender is unknown', () async {
      final SearchProfilesController c = await _boot(
        myGender: null,
        results: <SearchProfileModel>[_profile(1, '1'), _profile(2, '2')],
      );

      expect(c.visibleProfiles.length, 2);
    });

    test('ignored members are still hidden', () async {
      final SearchProfilesController c = await _boot(
        myGender: '1',
        results: <SearchProfileModel>[_profile(1, '2'), _profile(2, '2')],
      );

      c.ignoreProfile(1);

      expect(c.visibleProfiles.map((SearchProfileModel p) => p.id), <int>[2]);
    });
  });

  group('gender that arrives late', () {
    test('the first search already carries it, not the second', () async {
      // The profile is fetched lazily, so Discover can open before the member's
      // gender is known. The grid waits instead of listing both genders.
      await _boot(myGender: '2', results: <SearchProfileModel>[]);

      expect(_search.calls, hasLength(1));
      expect(_search.calls.single.gender, '1');
    });
  });

  group('the badge does not count the rule as a filter', () {
    test('a pinned gender alone leaves the filter count at zero', () async {
      final SearchProfilesController c =
          await _boot(myGender: '1', results: <SearchProfileModel>[]);

      expect(c.filter.value.gender, '2');
      expect(c.activeFilterCount, 0);
      expect(c.filter.value.hasFilters, isFalse);
    });

    test('a real filter still counts', () async {
      final SearchProfilesController c =
          await _boot(myGender: '1', results: <SearchProfileModel>[]);

      c.applyFilter(c.filter.value.copyWith(religionId: 1));
      await Future<void>.delayed(Duration.zero);

      expect(c.activeFilterCount, 1);
    });
  });

  test('a member whose gender only exists on the user record still works',
      () async {
    // Fallback path: no ProfileController in play, gender read off /auth/me.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final _FakeSearchRepository search =
        _FakeSearchRepository(<SearchProfileModel>[]);
    Get.put<SearchRepository>(search);
    Get.put<LookupController>(LookupController(LookupRepository(_client())));
    final AuthController auth = AuthController(
      authRepository: AuthRepository(_client()),
      storage: SecureStorageService(),
      currentUser: CurrentUserService(prefs),
    );
    auth.user.value = const UserModel(id: 7, gender: '2');
    Get.put<AuthController>(auth);

    Get.put<SearchProfilesController>(SearchProfilesController(
      repository: search,
      lookupController: Get.find<LookupController>(),
    ));
    await Future<void>.delayed(Duration.zero);

    expect(search.lastFilter.gender, '1');
  });
}
