import 'dart:async';

import 'package:flutter/widgets.dart';

import 'dates.dart';

/// Calls back when the calendar day changes underneath a screen.
///
/// The check-in code is per-day, and the screens that show it are the ones most
/// likely to still be open when the day turns over: a phone propped against a
/// till is the intended use, not an edge case. When that happens the code on
/// screen is dead, and the only symptom is every customer's scan failing as
/// `code_invalid` until somebody thinks to reopen the screen.
///
/// Two triggers, because either one alone leaves a real gap:
///
///  - **resume**, for the phone that was picked up in the morning. A backgrounded
///    app gets no timers worth relying on.
///  - **a poll**, for the phone that was never backgrounded at all. These screens
///    hold a wakelock precisely so they stay up all night, so the app can be
///    foregrounded straight through midnight and never see a lifecycle event.
///
/// Polling a clock rather than scheduling one timer at midnight is deliberate:
/// a timer for "in 7 hours" does not survive the device sleeping, and it gets
/// the wrong answer when the clock is changed or the phone crosses a timezone.
/// Comparing today against the day we loaded is correct however time moved.
class DayRollover with WidgetsBindingObserver {
  DayRollover({required this.onNewDay, this.pollInterval = _defaultPoll});

  /// Called once per day change, on the day it changes.
  final VoidCallback onNewDay;

  /// How often the clock is checked. A minute is far below the resolution that
  /// matters and costs nothing next to a screen that is already lit.
  final Duration pollInterval;

  static const _defaultPoll = Duration(minutes: 1);

  Timer? _timer;
  String? _day;

  /// Begin watching, from [day] — the day whatever is on screen belongs to.
  void start(String day) {
    _day = day;
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(pollInterval, (_) => check());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  /// Fire [onNewDay] if the day moved. Public so the screens that already know
  /// they need to re-check — on a manual refresh, say — share this one answer
  /// about what "a new day" means.
  void check() {
    final day = _day;
    if (day == null || day == todayString()) return;
    // Cleared first: the callback reloads and calls [start] again with the new
    // day, and until it does there is nothing to compare against.
    _day = null;
    onNewDay();
  }
}
