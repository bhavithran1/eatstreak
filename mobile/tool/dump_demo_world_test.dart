// Emit the demo world exactly as the app persists it, so tool/e2e/ can put an
// already-onboarded device together without anyone tapping through onboarding.
//
// Deliberately not in `test/`: `flutter test` would pick it up and it writes a
// file, which is not what a test is for. Run it by path:
//
//     flutter test tool/dump_demo_world_test.dart
//
// It prints nothing and asserts nothing interesting; the point is the JSON it
// writes to build/demo_world.json. The value comes from DemoRepository.seed —
// the same call onboarding makes — so the harness never has to reimplement the
// seed in Python, which would be one more pair of things that must agree and
// silently would not.
import 'dart:io';

import 'package:eatstreak/data/repositories/demo_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('writes the onboarded demo world to build/demo_world.json', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Flagged because this file sits outside `test/` — deliberately, so
    // `flutter test` does not pick up a file whose job is to write an artefact.
    // It is still only ever run by flutter_test.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});

    await DemoRepository().seed('You');

    final prefs = await SharedPreferences.getInstance();
    final world = prefs.getString('eatstreak.demo.v1');
    expect(world, isNotNull, reason: 'seed() must persist the world');
    expect(world, contains('"role":"customer"'));

    final out = File('build/demo_world.json')..createSync(recursive: true);
    out.writeAsStringSync(world!);
  });
}
