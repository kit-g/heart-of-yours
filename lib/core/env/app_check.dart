import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:heart/core/env/config.dart';

/// Attests that requests carrying this app's Firebase credentials come from
/// this app, on a genuine device.
///
/// The gap it closes is the anonymous session: `signInAnonymously` needs
/// nothing but the public config that ships inside every copy of the app, so
/// without attestation a script can mint uids for free, indefinitely. App
/// Check makes Firebase ask the platform to vouch for the caller first — App
/// Attest on iOS, Play Integrity on Android.
///
/// **Activation alone enforces nothing.** It makes the app *send* tokens;
/// whether Firebase then rejects requests without one is a per-service switch
/// in the console, and the order matters — turn enforcement on before the
/// attested builds are the ones in people's hands and the unattested ones stop
/// working. Monitoring first, until the console's "verified" share is boring.
///
/// heart-api is deliberately not covered yet. Reaching it would mean sending
/// `X-Firebase-AppCheck` on every call, and that header has to be allowed
/// through CORS and verified server-side before the client starts sending it,
/// or dev web breaks on a preflight the API answers with a closed allow-list.
/// See the handoff.
Future<void> initAppCheck(
  Env env, {
  void Function(dynamic error, {dynamic stacktrace})? onError,
}) async {
  // The web would need a reCAPTCHA site key and an origin registered against
  // it. There is no browser client in production — the API's CORS allowlist is
  // empty there — so there is nothing to attest.
  if (kIsWeb) return;

  // Debug builds cannot attest: App Attest and Play Integrity both refuse an
  // unsigned, sideloaded or simulated build. The debug provider stands in,
  // printing a token on first run that has to be registered in the console
  // before that machine counts as verified — per machine, and per CI runner.
  final debug = kDebugMode || env != .prod;

  try {
    await FirebaseAppCheck.instance.activate(
      providerApple: switch (debug) {
        true => const AppleDebugProvider(),
        false => const AppleAppAttestProvider(),
      },
      providerAndroid: switch (debug) {
        true => const AndroidDebugProvider(),
        false => const AndroidPlayIntegrityProvider(),
      },
    );
  } catch (error, stacktrace) {
    // Never fatal. An attestation this app cannot obtain is a request Firebase
    // may refuse once enforcement is on, but it is not a reason to fail a
    // launch that would otherwise work — least of all on the device of someone
    // whose Play Services are simply out of date.
    onError?.call(error, stacktrace: stacktrace);
  }
}
