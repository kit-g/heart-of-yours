/// Sets up URL strategy for the web app
library;

export 'none.dart' if (dart.library.io) 'io.dart' if (dart.library.js_interop) 'web.dart';
