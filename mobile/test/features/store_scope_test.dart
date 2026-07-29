import 'package:eatstreak/data/repositories/firestore_repository.dart';
import 'package:eatstreak/features/shared/widgets/store_scope.dart';
import 'package:eatstreak/state/store_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The failure screen has to say what failed.
///
/// It used to discard the error and print "Check your connection and try again"
/// for every one of them, which sent the user to reboot their router while the
/// real cause — a denied rule, a missing index, a document the app can't parse —
/// stayed invisible. The phone's own screen is the only place we can read it.
void main() {
  Future<void> pumpWithError(WidgetTester tester, Object error) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeControllerProvider.overrideWith(() => _FailingStore(error)),
        ],
        child: MaterialApp(
          home: StoreScope(builder: (_, _) => const Text('loaded')),
        ),
      ),
    );
    // Long enough to outlast every retry the policy allows, so what is on
    // screen at the end is the settled failure and not a spinner mid-backoff.
    await tester.pump();
    await tester.pump(
      storeLoadRetryDelay * (maxStoreLoadRetries + 1),
    );
    await tester.pump();
  }

  testWidgets('names the read and the code behind the friendly sentence',
      (tester) async {
    await pumpWithError(
      tester,
      StoreLoadException('visits', _Coded('permission-denied')),
    );

    expect(find.text("Couldn't load your data"), findsOneWidget);
    expect(find.text("You don't have access to do that."), findsOneWidget,
        reason: 'a denied rule is not a connection problem and must not say so');
    expect(find.text('visits · permission-denied'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('an unparseable document is named by path', (tester) async {
    await pumpWithError(
      tester,
      StoreLoadException(
        'shops',
        DocumentParseException('shops/abc123', TypeError()),
      ),
    );

    expect(find.text('shops · bad-document shops/abc123'), findsOneWidget);
  });

  testWidgets('a real network failure still reads as one', (tester) async {
    await pumpWithError(tester, StoreLoadException('shops', _Coded('unavailable')));

    expect(
      find.text('Network problem — check your connection and try again.'),
      findsOneWidget,
    );
  });
}

class _Coded implements Exception {
  _Coded(this.code);
  final String code;
}

class _FailingStore extends StoreController {
  _FailingStore(this.error);

  final Object error;

  @override
  Future<StoreState> build() async => throw error;
}
