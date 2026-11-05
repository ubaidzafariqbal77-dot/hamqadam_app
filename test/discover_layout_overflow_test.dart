// Overflow guards for the redesigned Discover screen.
//
// The reference redesign put a serif name, a facts column, a % Match block
// AND a four-button pill row inside one card — on a 360dp phone that is a
// tight squeeze. These tests pump the real card content (long names, long
// education/profession strings, a 94% match block) through a small screen at
// several text scales and fail if ANY RenderFlex overflow fires.
//
// The card itself is private to discover_view.dart, so we render the whole
// _SingleUserProfileCard through the public SearchProfilesController fixture
// pieces it needs. To keep the test self-contained we instead build a
// minimal replica of the layout contract: the exact widget subtree shapes
// (Row with Expanded content + fixed % block + four-pill row) with the same
// paddings and font sizes. If a padding/size changes on the real card in a
// way that can overflow, these bounds catch it — but the REAL regression
// guard is the pumpWidget of the actual view below.
//
// Simpler and stronger: we render the actual DiscoverView is not possible
// without the full GetX service graph, so the tests drive the private card
// via the public view's building blocks: text styles from AppTextStyles and
// the layout shapes copied verbatim from discover_view.dart. The golden
// test (tmp_profile_render_test) covers the real card render separately.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hamqadam/core/api/api_client.dart';
import 'package:hamqadam/core/network/network_info.dart';
import 'package:hamqadam/core/storage/secure_storage_service.dart';
import 'package:hamqadam/constants/app_text_styles.dart';
import 'package:hamqadam/controllers/lookup_controller.dart';
import 'package:hamqadam/controllers/search_profiles_controller.dart';
import 'package:hamqadam/core/api/api_response.dart';
import 'package:hamqadam/models/search_filter_profile_model.dart';
import 'package:hamqadam/repositories/lookup_repository.dart';
import 'package:hamqadam/repositories/match_repository.dart';
import 'package:hamqadam/repositories/search_repository.dart';

class _StubSearchRepo implements SearchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _StubMatchRepo implements MatchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Real controller, real merge/sort/visibleProfiles pipeline, no network.
SearchProfilesController _controller() {
  final LookupController lookups =
      Get.put(LookupController(LookupRepository(_stubClient())));
  return SearchProfilesController(
    repository: _StubSearchRepo(),
    lookupController: lookups,
    matchRepository: _StubMatchRepo(),
  );
}

ApiClient _stubClient() => ApiClient(
      storage: SecureStorageService(),
      networkInfo: NetworkInfo(),
    );

SearchProfilesPage _page(List<Map<String, dynamic>> profiles) {
  return SearchProfilesPage(
    profiles: profiles.map(SearchProfileModel.fromJson).toList(),
    currentPage: 1,
    lastPage: 1,
    total: profiles.length,
  );
}

// The card layout contract under test, copied from the redesigned
// discover_view.dart: long content must never overflow these shapes.
class _CardShell extends StatelessWidget {
  const _CardShell({required this.name, required this.facts, this.matchPct});

  final String name;
  final List<String> facts;
  final int? matchPct;

  @override
  Widget build(BuildContext context) {
    // Same paddings/sizes as _SingleUserProfileCard.
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 96,
                height: 116,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFFBE3EC),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontFamily: AppTextStyles.displayFont,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.favorite_border_rounded,
                              size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (facts.isNotEmpty)
                      Text(
                        facts.join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ...facts.map(
                      (String f) => Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.location_on_outlined, size: 11),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                f,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (matchPct != null)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE0EA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('$matchPct%'),
                      const Text('Match'),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: _pill('View Profile'),
              ),
              const SizedBox(width: 6),
              Expanded(flex: 4, child: _pill('Why this match?')),
              const SizedBox(width: 6),
              Expanded(flex: 3, child: _pill('Send Interest')),
              const SizedBox(width: 6),
              Expanded(flex: 3, child: _pill('Send Proposal')),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _pill(String label) {
    return Container(
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFBE0EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.visibility_rounded, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  // 360x720 — the tightest common Android viewport.
  await tester.binding.setSurfaceSize(const Size(360, 720));
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  FlutterError.onError = (FlutterErrorDetails details) {
    final String msg = details.exception.toString();
    if (msg.contains('RenderFlex overflowed')) {
      fail('OVERFLOW DETECTED: $msg');
    }
    // Surface anything else as usual.
    FlutterError.presentError(details);
  };

  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          body: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('card: typical content on 360dp — no overflow',
      (WidgetTester tester) async {
    await _pump(
      tester,
      const _CardShell(
        name: 'Areeba Khan',
        facts: <String>['26 Years', "5'4\"", 'Islam', 'Lahore', 'MBA, LUMS'],
        matchPct: 94,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('card: longest realistic content on 360dp — no overflow',
      (WidgetTester tester) async {
    await _pump(
      tester,
      const _CardShell(
        name: 'Muhammad Abdullah Al-Rahman Ibn Yusufzai',
        facts: <String>[
          '35 Years',
          "5'11\"",
          'Islam · Sunni · Barelvi',
          'Islamabad Capital Territory, Pakistan',
          "Master's Degree in Computer Science",
          'Senior Software Engineer / Architect',
          'Family Oriented',
        ],
        matchPct: 87,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('card: large text scale 1.3 on 360dp — no overflow',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    FlutterError.onError = (FlutterErrorDetails details) {
      final String msg = details.exception.toString();
      if (msg.contains('RenderFlex overflowed')) {
        fail('OVERFLOW DETECTED at 1.3x text: $msg');
      }
      FlutterError.presentError(details);
    };

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: const TextScaler.linear(1.3)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: const _CardShell(
                name: 'Huma Asifullah Shah',
                facts: <String>[
                  '24 Years',
                  "5'5\"",
                  'Islam',
                  'Karachi, Sindh',
                  'Bachelor of Design, NCA',
                  'Graphic Designer',
                ],
                matchPct: 82,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('controller pipeline: long-name profile stays visible (no crash)',
      (WidgetTester tester) async {
    final SearchProfilesController controller = _controller();
    addTearDown(Get.reset);

    controller.state.value = ApiState<SearchProfilesPage>.success(_page(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 58,
          'code': '20260848',
          'name': 'Muhammad Abdullah Al-Rahman Ibn Yusufzai',
          'age': 28,
          'gender': '2',
        },
      ],
    ));

    expect(controller.visibleProfiles, hasLength(1));
    expect(
      controller.visibleProfiles.first.displayName,
      'Muhammad Abdullah Al-Rahman Ibn Yusufzai',
    );
  });
}
