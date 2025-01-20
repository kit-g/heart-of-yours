# Heart of yours

Every beat counts.

## Introduction

Heart of yours is a minimalist fitness tracker mobile app that collects and aggregates your workout data. It is also a
showcase of a real-live serverless Flutter project.

## Prerequisites

- Dart 3.6+
- Flutter 3.27+
- a Firebase account
- XCode (for iOS)

## Architecture overview

The project has the following general structure.

```
├── README.md
├── analysis_options.yaml
├── android
    └──...
├── assets
    └── fonts
├── env
    └── dev.json
        ...
├── firebase.json
├── ios
    └── ...
├── lib
    ├── core
    ├── firebase_options.dart
    ├── firestore.rules
    ├── main.dart
    └── presentation
├── pubspec.yaml
├── shared
    ├── heart_language
    ├── heart_models
    └── heart_state
└── test
    └── ...
```

This is a slightly modified MVVM-architecture where the data layer is moved to its own package (or two, rather -
`heart_models` and `heart_state`), plus the same happened to the app's copy (`heart_language`). In this specific app,
there are no services (or service abstractions) since its backend is in Firebase and the Firestore connection is private
to the `heart_state` package and is not exposed to the app. In fact, the app has no direct dependency on Firebase and
this is how separation of concerns is achieved.
