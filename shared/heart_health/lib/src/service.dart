part of '../heart_health.dart';

/// The channel the host app must answer for Android's health permissions.
///
/// Declared here and implemented in `MainActivity`, because the destination is
/// an implicit Android intent rather than a URL: `url_launcher` cannot fire one
/// and this package has no native side of its own. iOS needs nothing — its
/// destination really is a URL.
///
/// One method, `openHealthConnectSettings`, returning whether the screen opened.
const healthPlatformChannel = 'heart_health/platform';

/// Access to the device's health store — HealthKit on iOS, Health Connect on
/// Android.
///
/// Reads six metrics; writes exactly one thing, a finished workout. See
/// [writeWorkout] for why that asymmetry is deliberate and where it stops.
///
/// An interface so state and tests never touch the plugin. The only
/// implementations are [DeviceHealthStore] and [UnsupportedHealthStore]; pick
/// one with [DeviceHealthStore.forPlatform].
///
/// **Nothing read through here may be sent to a server.** Health data is
/// device-only by decision — the OS store is already the system of record and
/// already backed up, so copying it up buys nothing but liability. The write
/// does not qualify that: it goes to the user's own device store, never
/// outward. See `docs/2026-08-02.wearables.md`.
abstract interface class HealthService {
  /// Whether this platform has a health store at all. False on web and desktop,
  /// where every other method is a no-op returning empty.
  bool get isSupported;

  /// Whether the store can be reached right now.
  ///
  /// Always [HealthStoreStatus.available] on a supported iOS device. On Android
  /// it can report that Health Connect is missing or too old, which is a state
  /// the user can fix — hence [openInstaller].
  Future<HealthStoreStatus> status();

  /// What we know about read access to [metrics].
  ///
  /// Read [HealthAccess.unknown]'s documentation before building UI on this. On
  /// iOS the honest answer is almost always "unknown", and that is not a bug.
  Future<HealthAccess> access(Set<HealthMetric> metrics);

  /// Shows the OS permission sheet for [metrics], plus write access for
  /// workouts.
  ///
  /// Read for every metric, write for the workout type and nothing else. The
  /// asymmetry is the point: Heart reads the body's data and writes back only
  /// the session it just watched the user do. One sheet, because the platforms
  /// only give us one and asking twice for a feature this small is worse than
  /// asking once for both.
  ///
  /// Returns whether the sheet was presented without error — **not** whether
  /// the user granted anything. On iOS those are genuinely different questions
  /// and only the first is answerable. Call [read] afterwards and see whether
  /// data arrives; for the write, see whether [writeWorkout] returns true.
  Future<bool> requestAccess(Set<HealthMetric> metrics);

  /// Every sample of [metrics] overlapping `[from, to)`.
  ///
  /// Faithful to the store: samples from different sources covering the same
  /// window are all returned, because they are distinct readings rather than
  /// duplicates. Summing them is a bug for any [HealthMetric.isCumulative]
  /// metric — see [HealthSample.source].
  ///
  /// Returns empty rather than throwing when access was refused; a refusal is
  /// a normal state, not an error.
  Future<List<HealthSample>> read({
    required Set<HealthMetric> metrics,
    required DateTime from,
    required DateTime to,
  });

  /// Whether the store will accept a workout write.
  ///
  /// Only ever [HealthAccess.granted] or [HealthAccess.denied], and *denied
  /// does not mean the user said no*. HealthKit distinguishes `notDetermined`
  /// from `sharingDenied`, but the plugin's iOS bridge collapses both into one
  /// false (`status == .sharingAuthorized`), and Health Connect reports only
  /// the set of permissions granted. So "never asked" and "asked and refused"
  /// are the same answer here, on both platforms.
  ///
  /// The consequence is the whole shape of [requestWorkoutWriteAccess]: since
  /// a refusal cannot be told apart from silence, not-granted has to be treated
  /// as worth asking about, and it is the platform — not this code — that
  /// decides whether a sheet actually appears.
  Future<HealthAccess> workoutWriteAccess();

  /// Asks for permission to write workouts, and nothing else.
  ///
  /// Separate from [requestAccess] because the two are asked at different
  /// moments and, for anyone who granted read access before Heart could write,
  /// [requestAccess] will never run again — the settings row stops offering it
  /// once the sheet has been shown once. Without this method those users have
  /// no route to write access at all: the platform's own permission screen
  /// lists only the types an app has actually requested, so the toggle they
  /// would need does not exist until Heart asks for it here.
  ///
  /// Safe to call when the user has already refused: both platforms show a
  /// sheet only for an undetermined permission, so a second ask is a no-op
  /// rather than nagging. That is what makes it usable despite
  /// [workoutWriteAccess] being unable to tell refusal from silence — but it
  /// also means a true reports the sheet was presented without error, never
  /// that anything was granted. Read [workoutWriteAccess] afterwards for that.
  Future<bool> requestWorkoutWriteAccess();

  /// Saves a finished strength-training session to the store.
  ///
  /// The one thing this package writes. Everything else is read-only, and the
  /// permission [requestAccess] asks for reflects that: write is requested for
  /// the workout type alone.
  ///
  /// **Energy is deliberately absent, and must stay absent.** Without a watch
  /// session there is no measurement of what the user burned, only an estimate
  /// from bodyweight and duration. A number Heart invented, sitting next to the
  /// Watch's own reading and disagreeing with it, is worse than no number —
  /// so the session carries its duration and its activity type and nothing
  /// else. See `docs/2026-08-02.wearables.md` §"Tier 1".
  ///
  /// [activity] is what the user actually did — see [WorkoutActivity], and
  /// note that deciding it is the caller's job, because only the caller knows
  /// which exercises the session contained.
  ///
  /// [title] is copy and comes from the caller; this package does not name
  /// things. Health Connect shows it, HealthKit ignores it.
  ///
  /// Returns whether the store accepted it. False covers a refused permission
  /// as well as a genuine failure — the platforms do not distinguish, and the
  /// caller's response to both is the same: nothing. A workout that failed to
  /// write is not retried, because by the time we could the user has moved on
  /// and a session appearing in Health hours late is its own bug.
  Future<bool> writeWorkout({
    required WorkoutActivity activity,
    required DateTime start,
    required DateTime end,
    String? title,
  });

  /// Asks for access to data older than 30 days. Android only; true elsewhere.
  ///
  /// Health Connect answers every read with the last 30 days unless this is
  /// *separately* granted — the manifest entry and the six data permissions do
  /// nothing for it. Without it the backfill walks years in chunks and comes
  /// home with a month, silently, because a withheld window and an empty one
  /// are the same empty list.
  ///
  /// Separate from [requestAccess] because it is a separate prompt, and the
  /// moment to show it is not always the moment the data permissions are asked
  /// for: a user who granted through the platform's own settings never passes
  /// through [requestAccess] at all.
  Future<bool> requestHistoryAccess();

  /// Sends the user to install or update Health Connect. Android only; a no-op
  /// everywhere else.
  Future<void> openInstaller();

  /// Opens wherever this platform keeps health permissions, and says whether it
  /// got there.
  ///
  /// **The app's own page in the OS settings is the wrong place, and it is the
  /// obvious wrong place.** iOS does not list HealthKit access there: Settings ›
  /// Heart offers cellular data, Siri and search, and no mention of health at
  /// all. Read access lives in the Health app, under the user's profile.
  ///
  /// Returns false when this platform has nowhere to send them — then, and only
  /// then, is falling back to the app's settings page better than nothing.
  Future<bool> openPermissions();
}

/// Whether the device's health store can be used.
enum HealthStoreStatus {
  available,

  /// Health Connect is not installed, or the platform has no store at all.
  /// Recoverable on Android via [HealthService.openInstaller].
  unavailable,

  /// Health Connect is installed but too old. Also recoverable.
  needsUpdate,
}

/// What is known about read access.
enum HealthAccess {
  granted,
  denied,

  /// The platform will not say.
  ///
  /// This is the normal iOS answer and the reason [HealthService.requestAccess]
  /// promises so little. HealthKit deliberately refuses to disclose whether
  /// *read* permission was granted, because telling an app "you may not see the
  /// user's heart data" leaks that the user has heart data to hide. The API
  /// returns the same thing whether the user granted everything or nothing.
  ///
  /// Practical consequence: **never render a "Health connected ✓" state from a
  /// permission check.** The only evidence that access exists is samples coming
  /// back from [HealthService.read]. Drive the UI off whether there is data,
  /// and when there is none, say so neutrally — "no data yet" is true whether
  /// the user declined or simply hasn't worn a watch.
  unknown,
}
