part of 'api.dart';

abstract final class Router {
  static const accounts = 'v1/accounts';
  static const exercises = 'v1/exercises';
  static const exercisePreferences = 'v1/exercise-preferences';
  static const feedback = 'v1/feedback';
  static const goals = 'v1/goals';
  static const templates = 'v1/templates';
  static const templateFolders = 'v1/template-folders';
  static const workouts = 'v1/workouts';
  static const workoutImports = '$workouts/imports';
  static const accountTokens = '$accounts/tokens';
  static const programs = 'v1/programs';
  static const connections = 'v1/connections';
  static const invitations = 'v1/invitations';
  static const invitationLinks = 'v1/invitation-links';
  static const blocks = 'v1/blocks';
  static const coachClients = 'v1/coach/clients';
  static const coachFeed = 'v1/coach/feed';
  static const libraryPrograms = 'v1/library-programs';
  static const devices = 'v1/devices';
  static const deviceRemovals = 'v1/devices/removals';
  static const pushSettings = 'v1/push/settings';

  /// A push topic's setting. Topics are the server's words, dotted
  /// (`coaching.message`), and one is held to that shape before it reaches a
  /// path, as an invitation's token is.
  static String pushSetting(String topic) {
    if (!_pushTopic.hasMatch(topic)) {
      throw ArgumentError.value(topic, 'topic', 'not a push topic');
    }
    return '$pushSettings/$topic';
  }

  static final _pushTopic = RegExp(r'^[a-z0-9_]+(\.[a-z0-9_]+)*$');

  // device keys and key delivery (#555)
  static const _keys = 'v1/keys';
  static const cryptoDevices = '$_keys/devices';
  static const keyQueue = '$_keys/queue';
  static const keyQueueConfirmations = '$keyQueue/confirmations';

  /// A device by the UUID it chose for itself. Held to that shape before it
  /// reaches a path, as an invitation's token is: an id read off the server or
  /// a queue item must not send the account's requests anywhere else.
  static String cryptoDevice(String deviceId) {
    if (!_uuid.hasMatch(deviceId)) {
      throw ArgumentError.value(deviceId, 'deviceId', 'not a device id');
    }
    return '$cryptoDevices/$deviceId';
  }

  static String oneTimeKeys(String deviceId) => '${cryptoDevice(deviceId)}/one-time-keys';

  static String fallbackKey(String deviceId) => '${cryptoDevice(deviceId)}/fallback';

  static String cryptoDeviceVouch(String deviceId) => '${cryptoDevice(deviceId)}/vouch';

  /// Someone's keys to take, by their account id.
  static String keyClaims(String userId) {
    if (!_userId.hasMatch(userId)) {
      throw ArgumentError.value(userId, 'userId', 'not an account id');
    }
    return '$_keys/claims/$userId';
  }

  static final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  static final _userId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  static String libraryProgram(String programId) => '$libraryPrograms/$programId';

  static String libraryHolders(String programId) => '${libraryProgram(programId)}/holders';

  static String librarySend(String programId) => '${libraryProgram(programId)}/send';

  /// Where a coach says they have looked at a client, by the connection's id.
  static String coachClientReviewed(String connectionId) => '$coachClients/$connectionId/reviewed';

  static String clientWorkouts(String studentId) => '$accounts/$studentId/workouts';

  static String clientSkips(String studentId) => '$accounts/$studentId/skips';

  static String clientWorkoutPlan(String studentId, String workoutId) {
    return '$accounts/$studentId/workouts/$workoutId/plan';
  }

  static String invitation(String invitationId) => '$invitations/$invitationId';

  static String invitationResend(String invitationId) => '${invitation(invitationId)}/resend';

  /// A link by its secret. The token comes from a link anyone can write, so
  /// it is held to what the server makes, base64url, before it reaches a path:
  /// `Uri.https` resolves `..`, and an unchecked one would send the account's
  /// requests anywhere on the API.
  static String invitationLink(String token) {
    if (!_invitationToken.hasMatch(token)) {
      throw ArgumentError.value(token, 'token', 'not an invitation token');
    }
    return '$invitationLinks/$token';
  }

  static final _invitationToken = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  static String invitationLinkAccept(String token) => '${invitationLink(token)}/accept';

  static String invitationLinkDecline(String token) => '${invitationLink(token)}/decline';

  static String invitationLinkBlock(String token) => '${invitationLink(token)}/block';

  static String block(String userId) => '$blocks/$userId';
  static const hiddenWorkouts = '$workouts/hidden';

  /// A connection by its `connectionId`, a UUID.
  static String connection(String connectionId) {
    return '$connections/$connectionId';
  }

  static String connectionShares(String connectionId) {
    return '${connection(connectionId)}/shares';
  }

  static String workoutHidden(String workoutId) {
    return '$workouts/$workoutId/hidden';
  }

  static String program(String programId) {
    return '$programs/$programId';
  }

  /// Where a student starts a coach's copy that waits for them (#557).
  static String programStart(String programId) => '${program(programId)}/start';

  static String programActions(String programId) {
    return '$programs/$programId/actions';
  }

  static String programAction(String programId, String actionId) {
    return '$programs/$programId/actions/$actionId';
  }

  static String programBases(String programId) {
    return '$programs/$programId/bases';
  }

  static String programBase(String programId, String baseId) {
    return '$programs/$programId/bases/$baseId';
  }

  static const skips = 'v1/skips';
  static const anomalies = 'v1/anomalies';

  static String anomaly(String anomalyId) {
    return '$anomalies/$anomalyId';
  }

  static String skip(String skipId) {
    return '$skips/$skipId';
  }

  static String goal(String goalId) {
    return '$goals/$goalId';
  }

  static String userGoals(String targetUserId) {
    return '$accounts/$targetUserId/goals';
  }

  static String userWorkout(String targetUserId, String workoutId) {
    return '$accounts/$targetUserId/workouts/$workoutId';
  }

  static String goalStage(String goalId, String stageId) {
    return '$goals/$goalId/stages/$stageId';
  }

  static String workoutImages(String workoutId) {
    return '$workouts/$workoutId/images';
  }

  static String template(String templateId) {
    return '$templates/$templateId';
  }

  static String templateFolder(String folderId) {
    return '$templateFolders/$folderId';
  }

  static String folderShare(String targetUserId, String folderId) {
    return '$accounts/$targetUserId/folders/$folderId';
  }

  static String workout(String workoutId) {
    return '$workouts/$workoutId';
  }

  static String workoutPlan(String workoutId) {
    return '$workouts/$workoutId/plan';
  }

  static String accountToken(String tokenId) {
    return '$accountTokens/$tokenId';
  }

  static String exerciseMoves(String exerciseId) {
    return '$exercises/$exerciseId/moves';
  }
}
