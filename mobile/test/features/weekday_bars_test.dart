import 'package:eatstreak/features/owner/widgets/weekday_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A day the shop was shut must not draw a bar.
///
/// The bars carry a 4% floor so a quiet day stays visible rather than
/// disappearing into the axis. Applied to a zero it invents trade that never
/// happened — a stub under a closed Sunday, which to the glance this chart is
/// for reads as "busy every day".
void main() {
  Future<List<double?>> heightFactors(
    WidgetTester tester,
    List<int> counts,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WeekdayBars(counts: counts)),
      ),
    );
    return tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .map((b) => b.heightFactor)
        .toList();
  }

  testWidgets('a day with no visits draws nothing', (tester) async {
    final factors = await heightFactors(tester, [10, 0, 5, 0, 0, 2, 8]);

    expect(factors, hasLength(7));
    expect(factors[1], 0.0, reason: 'Tuesday had no visits');
    expect(factors[3], 0.0);
    expect(factors[4], 0.0);
  });

  testWidgets('a quiet day still shows above the floor', (tester) async {
    // 1 against a peak of 100 is 1%, below the 4% floor — it has to stay
    // visible, which is what the floor is for.
    final factors = await heightFactors(tester, [100, 1, 0, 0, 0, 0, 0]);

    expect(factors[0], 1.0);
    expect(factors[1], greaterThan(0.0));
    expect(factors[2], 0.0);
  });

  testWidgets('a shop with no visits at all says so instead of drawing bars',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WeekdayBars(counts: [0, 0, 0, 0, 0, 0, 0])),
      ),
    );

    expect(find.byType(FractionallySizedBox), findsNothing);
    expect(find.textContaining('No visits'), findsOneWidget);
  });
}
