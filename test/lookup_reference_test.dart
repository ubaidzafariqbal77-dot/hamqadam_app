import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/constants/app_lookups.dart';
import 'package:hamqadam/models/lookup_item_model.dart';
import 'package:hamqadam/repositories/lookup_repository.dart';

/// Guards the dropdown reference pipeline — the part of registration that used
/// to stall the UI. Two things have to hold:
///
///  * every list is converted AND indexed by parent id in one pass, so a
///    dependent dropdown (city→state) is a map lookup, not a 48 000-row scan;
///  * that whole structure survives a [compute] hop, because it is built on a
///    background isolate and handed to the UI isolate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildLookupLists', () {
    test('indexes dependent rows by their parent id', () {
      final Map<String, LookupList> lists = buildLookupLists(<String, dynamic>{
        'countries': <dynamic>[
          <String, dynamic>{'id': 166, 'name': 'Pakistan'},
          <String, dynamic>{'id': 101, 'name': 'India'},
        ],
        'states': <dynamic>[
          <String, dynamic>{'id': 2728, 'name': 'Punjab', 'country_id': 166},
          <String, dynamic>{'id': 2729, 'name': 'Sindh', 'country_id': 166},
          <String, dynamic>{'id': 1, 'name': 'Kerala', 'country_id': 101},
        ],
      });

      expect(
        lists['states']!.forParent(166).map((LookupItem s) => s.name),
        <String>['Punjab', 'Sindh'],
      );
      expect(lists['states']!.forParent(101).map((LookupItem s) => s.name), <String>['Kerala']);
      // A parent with no rows must come back empty, not fall back to the lot.
      expect(lists['states']!.forParent(999), isEmpty);
    });

    test('a list whose rows carry no parent ignores the parent filter', () {
      // Castes are documented as independent, so a stale parent id from another
      // dropdown must never blank the list.
      final Map<String, LookupList> lists = buildLookupLists(<String, dynamic>{
        'castes': <dynamic>[
          <String, dynamic>{'id': 1, 'name': 'Syed'},
          <String, dynamic>{'id': 2, 'name': 'Rajput'},
        ],
      });
      expect(lists['castes']!.hasParents, isFalse);
      expect(lists['castes']!.forParent(7).length, 2);
    });

    test('string rows become option items and empty lists are dropped', () {
      final Map<String, LookupList> lists = buildLookupLists(<String, dynamic>{
        'diet': <dynamic>['Vegetarian', 'Non-Vegetarian'],
        'nothing': <dynamic>[],
        'not_a_list': 'ignored',
      });
      expect(lists['diet']!.items.first.apiValue, 'Vegetarian');
      expect(lists.containsKey('nothing'), isFalse);
      expect(lists.containsKey('not_a_list'), isFalse);
    });
  });

  test('the built lists survive a compute() hop', () async {
    // The repository builds these on a background isolate; if LookupList or
    // LookupItem were ever made unsendable this is what would catch it.
    final Map<String, LookupList> lists = await compute(
      decodeAndBuildLookupLists,
      jsonEncode(<String, dynamic>{
        'cities': <dynamic>[
          <String, dynamic>{'id': 31439, 'name': 'Lahore', 'state_id': 2728},
        ],
      }),
    );
    expect(lists['cities']!.forParent(2728).single.name, 'Lahore');
  });

  test('the bundled asset covers every list registration warms up', () async {
    final String raw = await rootBundle.loadString('assets/lookups/dropdown_reference.json');
    final Map<String, LookupList> lists = decodeAndBuildLookupLists(raw);

    for (final String key in LookupKeys.preload) {
      expect(lists[key], isNotNull, reason: 'bundled asset is missing "$key"');
      expect(lists[key]!.items, isNotEmpty, reason: '"$key" is empty in the bundled asset');
    }

    // The two lists that made the flow slow, and the reason the index exists.
    expect(lists['cities']!.items.length, greaterThan(40000));
    expect(lists['cities']!.hasParents, isTrue);
    expect(lists['states']!.hasParents, isTrue);
  });
}
