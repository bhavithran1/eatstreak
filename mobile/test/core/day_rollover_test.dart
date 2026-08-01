import 'package:eatstreak/core/utils/day_rollover.dart';
import 'package:eatstreak/core/utils/dates.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The check-in code is per-day and the screens that show it are the ones left
/// propped against a till all night, so "the day changed while this was open" is
/// the normal case, not an edge one. When it is missed the failure is silent and
/// total: the QR looks fine and every customer's scan comes back `code_invalid`
/// until someone reopens the screen.
///
/// Untestable by hand — it takes until midnight — which is exactly why it is
/// pinned here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Poll fast so a test second stands in for a real minute.
  DayRollover watching(String day, VoidCallback onNewDay) {
    final r = DayRollover(
      onNewDay: onNewDay,
      pollInterval: const Duration(milliseconds: 10),
    );
    addTearDown(r.dispose);
    r.start(day);
    return r;
  }

  test('the same day does not fire', () async {
    var fired = 0;
    watching(todayString(), () => fired++);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(fired, 0, reason: 'nothing has changed; refetching would be noise');
  });

  test('a day that has already passed fires', () async {
    var fired = 0;
    watching('2020-01-01', () => fired++);

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(fired, greaterThan(0));
  });

  test('it fires once, not once per poll', () async {
    // The callback refetches over the network. Firing every tick would hammer
    // the backend all night from a phone nobody is holding.
    var fired = 0;
    watching('2020-01-01', () => fired++);

    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(fired, 1);
  });

  test('restarting on the new day re-arms it for the next one', () async {
    var fired = 0;
    late final DayRollover rollover;
    rollover = watching('2020-01-01', () {
      fired++;
      // What a screen does after a successful reload.
      rollover.start(fired == 1 ? '2020-01-02' : todayString());
    });

    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(fired, 2,
        reason: 'a second stale day must be caught, then today must settle it');
  });

  test('a stopped watcher goes quiet', () async {
    var fired = 0;
    final rollover = DayRollover(
      onNewDay: () => fired++,
      pollInterval: const Duration(milliseconds: 10),
    );
    rollover.start('2020-01-01');
    rollover.dispose();

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(fired, 0, reason: 'a disposed screen must not keep polling');
  });

  test('check() answers immediately, without waiting for a tick', () async {
    // The path a resume takes: the phone was picked up in the morning and the
    // answer has to be there before the first customer, not a poll later.
    var fired = 0;
    final rollover = DayRollover(
      onNewDay: () => fired++,
      pollInterval: const Duration(hours: 1),
    );
    addTearDown(rollover.dispose);
    rollover.start('2020-01-01');

    rollover.check();

    expect(fired, 1);
  });
}
