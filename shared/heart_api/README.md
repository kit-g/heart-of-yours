## Heart API

A thin, testable HTTP client for the Heart app backend. It provides a single entry point to Heart services (accounts, exercises, workouts, templates, feedback) and a small companion client for remote configuration. The package focuses on:
- A clear, typed boundary using models from heart_models.
- Simple header-based authentication (Bearer token).
- Minimal, predictable responses and error handling.
- Easy testing via injectable http.Client and a singleton factory pattern.

### Why this package
- Centralizes how the app talks to the Heart API in one place.
- Keeps networking concerns (base URL, headers, HTTP verbs, upload helpers) behind a small API.
- Encourages consistency and reuse across features (workouts, templates, feedback, etc.).

### What it includes
- Api (main client)
  - Accounts: register, delete, undo deletion, avatar upload/remove (via pre-signed forms)
  - Feedback: submit feedback with an optional screenshot upload
  - Exercises: read-only fetch
  - Workouts: create, delete, list (supports pageSize and since)
  - Templates: create, delete, list
  - Header auth utilities: authenticate(headers), isAuthenticated
- ConfigApi (config client)
  - Fetch remote config map
  - Fetch sample templates (public samples for onboarding/demo)

### Installation
This package is part of the monorepo and intended to be consumed from other packages/apps in this workspace. It depends on:
- heart_models for data structures and service interfaces
- network_utils for HTTP helpers (Requests mixin, upload helpers)
- http for the underlying client

Quick start
- Create an instance with your API gateway (base URL domain; https is used under the hood):

  ```dart
  import 'package:heart_api/heart_api.dart';
  import 'package:http/http.dart' as http;

  // Create or reuse a single instance per app runtime
  final api = Api(gateway: 'api.example.com', client: http.Client());

  // Authenticate once headers are available
  api.authenticate({
    'Authorization': 'Bearer <your-access-token>',
  });

  // Optional: check auth state before issuing calls
  final authed = api.isAuthenticated; // true if a non-empty Bearer token is set
  ```

- Basic operations:

  ```dart
  // Accounts
  final user = await api.registerAccount(User(id: 'u1', displayName: 'Jane'));
  await api.deleteAccount(accountId: user.id);
  await api.undoAccountDeletion(user.id);

  // Avatar upload flow: request pre-signed form, then upload
  final link = await api.getAvatarUploadLink(user.id, imageMimeType: 'image/png');
  if (link != null) {
    // file tuple: (fieldName, bytes, {filename?, contentType?})
    final screenshotBytes = <int>[]; // your bytes here
    await api.uploadAvatar(
      link,
      ('file', screenshotBytes, filename: 'avatar.png', contentType: 'image/png'),
    );
  }

  // Feedback with optional screenshot (Uint8List)
  final sent = await api.submitFeedback(feedback: 'Great app!', screenshot: null);

  // Exercises
  final exercises = await api.getExercises();

  // Workouts
  final created = await api.saveWorkout(Workout(...));
  final workouts = await api.getWorkouts((id) => /* lookup Exercise by id */ throw UnimplementedError(), pageSize: 20);
  final deleted = await api.deleteWorkout('workoutId');

  // Templates
  final saved = await api.saveTemplate(Template(...));
  final templates = await api.getTemplates((id) => /* lookup Exercise by id */ throw UnimplementedError());
  final removed = await api.deleteTemplate('templateId');
  ```

- Config API (public config and samples):

  ```dart
  final cfg = ConfigApi(gateway: 'config.example.com');
  final configMap = await cfg.getRemoteConfig();
  final samples = await cfg.getSampleTemplates((id) => /* lookup Exercise */ throw UnimplementedError());
  ```

### Behavior and error handling
- Base URL: gateway is a domain like api.example.com; URIs are built as HTTPS.
- Authentication: set headers via authenticate(Map<String,String> headers). Only Authorization: Bearer <token> is validated by isAuthenticated.
- Returns:
  - Many methods return bool or iterable/model instances.
  - Some methods return null when no data is available (e.g., getAvatarUploadLink when the backend doesn’t return a pre-signed payload; getWorkouts/getTemplates when JSON shape doesn’t match).
- Errors:
  - HTTP errors typically throw the parsed JSON Map from the backend for >=400 codes.
  - registerAccount throws AccountDeleted when the backend responds with {"code":"ACCOUNT_DELETED"}.

### Testing and http.Client injection
- Pass a custom http.Client in the Api factory for unit tests or special transports:

  ```dart
  final client = MockClient();
  final api = Api(gateway: 'api.example.com', client: client);
  ```

### Singleton/factory note
- Api and ConfigApi are implemented as singletons behind a factory. Calling Api(gateway: ...) updates the shared instance (Api.instance) and optional http client. Prefer creating and configuring them early in your app and reusing them.

### Source overview
- Endpoints:
  - v1/accounts, v1/exercises, v1/feedback, v1/templates, v1/workouts
- Key types and helpers:
  - User, Exercise, Workout, Template come from heart_models
  - Requests mixin (from network_utils) provides get/post/put/delete and uploadToBucket

### License and contributions
This package is internal to the Heart project. Issues and contributions should be made in this repository.
