/// Google sign-in button for web and non-web platforms
library;

export 'none.dart' if (dart.library.io) 'io.dart' if (dart.library.js_interop) 'web.dart';
