/// End-to-end encryption between devices, on vodozemac (Olm and Megolm).
///
/// It knows nothing about any app, server or store: the caller keeps the
/// state, moves the bytes and names its contexts. See the README for what a
/// caller has to do because the library won't.
library;

export 'src/exception.dart';
export 'src/sealbox.dart';
