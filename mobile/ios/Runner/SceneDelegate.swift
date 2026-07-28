import Flutter
import FirebaseCore
import UIKit

/// Holds incoming URLs back until Firebase has a default app.
///
/// `FLTFirebaseAuthPlugin` implements `scene:openURLContexts:` and calls
/// `Auth.auth()` on the way in. That call traps when no default `FirebaseApp`
/// has been configured:
///
///     FLTFirebaseAuthPlugin scene:openURLContexts: -> static Auth.auth()
///       -> _assertionFailure
///     FirebaseAuth/Auth.swift:153: The default FirebaseApp instance must be
///     configured before the default Auth instance can be initialized.
///
/// So forwarding a URL before Firebase is up does not fail the URL — it kills
/// the process. Two ways that happens:
///
///  - **Cold start from a check-in link.** `main()` awaits
///    `initializeFirebase()` before `runApp`, but UIKit delivers the URL on its
///    own schedule, and nothing orders those two. This is the app's primary
///    flow: scan a code, app launches from the link. Rare, and fatal when it
///    lands.
///  - **A demo-mode build**, which never configures Firebase at all
///    (see `main.dart`), so *every* incoming URL was fatal.
///
/// Deferring rather than dropping is what keeps the first case working: the
/// customer's check-in link survives the wait and is delivered a moment later,
/// instead of being lost with the process. A demo build never configures
/// Firebase, so its URLs are discarded once the window closes — deep links do
/// not function in demo mode, which is a real limitation but no longer a crash.
class SceneDelegate: FlutterSceneDelegate {

  /// How long to wait for Dart to finish `Firebase.initializeApp`. Generous
  /// next to a cold start, and short enough that a demo build's dropped link
  /// does not look like a hang.
  private static let maxWait: TimeInterval = 5

  /// Checked often enough that the delay is imperceptible on a real launch.
  private static let pollInterval: TimeInterval = 0.05

  private var deferred: [(scene: UIScene, contexts: Set<UIOpenURLContext>)] = []
  private var poll: Timer?
  private var waitingSince: Date?

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    guard FirebaseApp.app() == nil else {
      super.scene(scene, openURLContexts: URLContexts)
      return
    }

    deferred.append((scene, URLContexts))
    startPolling()
  }

  private func startPolling() {
    guard poll == nil else { return }
    waitingSince = Date()

    poll = Timer.scheduledTimer(
      withTimeInterval: Self.pollInterval,
      repeats: true
    ) { [weak self] timer in
      guard let self else {
        timer.invalidate()
        return
      }

      if FirebaseApp.app() != nil {
        self.stopPolling()
        self.flush()
        return
      }

      let waited = Date().timeIntervalSince(self.waitingSince ?? Date())
      if waited >= Self.maxWait {
        self.stopPolling()
        // Deliberately not forwarded: without a default app this is the call
        // that would trap. A demo build always ends up here.
        NSLog(
          "[EatStreak] Dropped %d URL delivery(ies): Firebase was never configured. "
            + "Expected in a demo-mode build; in a live build it means "
            + "Firebase.initializeApp did not complete within %.0fs.",
          self.deferred.count, Self.maxWait
        )
        self.deferred.removeAll()
      }
    }
  }

  private func stopPolling() {
    poll?.invalidate()
    poll = nil
    waitingSince = nil
  }

  private func flush() {
    let queued = deferred
    deferred.removeAll()
    for item in queued {
      super.scene(item.scene, openURLContexts: item.contexts)
    }
  }
}
