import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/models/search_filter_profile_model.dart';

void main() {
  group('SearchFilterModel — filters the API accepts but the sheet used to drop', () {
    // These parameter names come straight from ProfileSearchRequest; if one is
    // misspelled the API silently ignores it and the filter looks broken.
    test('sends every newly exposed filter under its API name', () {
      const SearchFilterModel f = SearchFilterModel(
        recentlyActive: true,
        newThisWeek: true,
        international: true,
        heightMin: 60,
        heightMax: 72,
        incomeMin: 50000,
        incomeMax: 200000,
        subCasteId: 7,
        sectId: 4,
        education: 'Masters',
        profession: 'Engineer',
        lifestyle: 'Vegetarian',
        languageId: 3,
      );

      final Map<String, dynamic> q = f.toQueryParams();

      expect(q['recently_active'], 1);
      expect(q['new_this_week'], 1);
      expect(q['international'], 1);
      expect(q['height_min'], 60);
      expect(q['height_max'], 72);
      expect(q['income_min'], 50000);
      expect(q['income_max'], 200000);
      expect(q['sub_caste_id'], 7);
      expect(q['sect_id'], 4);
      expect(q['education'], 'Masters');
      expect(q['profession'], 'Engineer');
      expect(q['lifestyle'], 'Vegetarian');
      expect(q['language_id'], 3);
    });

    test('unset filters are omitted entirely, never sent as null', () {
      const SearchFilterModel f = SearchFilterModel();
      final Map<String, dynamic> q = f.toQueryParams();

      for (final String key in <String>[
        'recently_active',
        'new_this_week',
        'international',
        'height_min',
        'height_max',
        'income_min',
        'income_max',
        'sub_caste_id',
        'sect_id',
        'education',
        'profession',
        'lifestyle',
        'language_id',
      ]) {
        expect(q.containsKey(key), isFalse, reason: key);
      }
    });

    test('blank text filters are not sent', () {
      const SearchFilterModel f = SearchFilterModel(
        education: '   ',
        profession: '',
      );
      final Map<String, dynamic> q = f.toQueryParams();

      expect(q.containsKey('education'), isFalse);
      expect(q.containsKey('profession'), isFalse);
    });

    test('every new filter is counted so the badge can return to zero', () {
      expect(const SearchFilterModel().activeFilterCount, 0);

      const SearchFilterModel all = SearchFilterModel(
        recentlyActive: true,
        newThisWeek: true,
        international: true,
        heightMin: 60,
        heightMax: 72,
        incomeMin: 1,
        incomeMax: 2,
        subCasteId: 7,
        sectId: 4,
        education: 'Masters',
        profession: 'Engineer',
        lifestyle: 'Vegetarian',
        languageId: 3,
      );

      // 3 booleans + height window + income window + subCaste + sect + education
      // + profession + lifestyle + language = 11. The two ranges count once
      // each, which the next assertion pins down separately.
      expect(all.activeFilterCount, 11);
      expect(all.hasFilters, isTrue);

      // A height WINDOW counts once, not once per bound.
      const SearchFilterModel oneWindow = SearchFilterModel(heightMin: 60, heightMax: 72);
      expect(oneWindow.activeFilterCount, 1);

      // Clearing them via copyWith must genuinely return to zero.
      final SearchFilterModel cleared = all.copyWith(
        recentlyActive: false,
        newThisWeek: false,
        international: false,
        clearHeightMin: true,
        clearHeightMax: true,
        clearIncomeMin: true,
        clearIncomeMax: true,
        clearSubCaste: true,
        clearSect: true,
        clearEducation: true,
        clearProfession: true,
        clearLifestyle: true,
        clearLanguage: true,
      );

      expect(cleared.activeFilterCount, 0);
      expect(cleared.hasFilters, isFalse);
    });

    test('copyWith preserves a filter that is not being changed', () {
      const SearchFilterModel base = SearchFilterModel(
        heightMin: 60,
        subCasteId: 7,
        education: 'Masters',
      );

      final SearchFilterModel changed = base.copyWith(newThisWeek: true);

      expect(changed.heightMin, 60);
      expect(changed.subCasteId, 7);
      expect(changed.education, 'Masters');
      expect(changed.newThisWeek, isTrue);
    });

    test('copyWith can override a value as well as clear it', () {
      const SearchFilterModel base = SearchFilterModel(heightMin: 60);
      expect(base.copyWith(heightMin: 66).heightMin, 66);
      expect(base.copyWith(clearHeightMin: true).heightMin, isNull);
    });

    test('the pre-existing filters still work untouched', () {
      const SearchFilterModel f = SearchFilterModel(
        ageMin: 25,
        ageMax: 35,
        onlineNow: true,
        mutualMatch: true,
        newProfiles: true,
      );

      final Map<String, dynamic> q = f.toQueryParams();

      expect(q['age_min'], 25);
      expect(q['age_max'], 35);
      expect(q['online_now'], 1);
      expect(q['mutual_match'], 1);
      expect(q['new_profiles'], 1);
      expect(f.activeFilterCount, 5);
    });
  });
}