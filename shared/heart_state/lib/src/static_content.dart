import 'dart:convert';

/// One file of static content from the CDN (#352, #396): kept on the device
/// between launches, and read again only when the CDN has a newer copy than
/// the one kept.
///
/// Nobody's data, and public: the same file for every account, kept through
/// sign-out. Until a file is first published every read fails, and [value]
/// simply stays null — no error, no empty page.
final class StaticContent<T extends Object> {
  /// The path the file is served at, and kept under.
  final String key;

  /// The file's newer copy, asked for conditionally on the kept copy's ETag:
  /// null when the one kept is still current.
  final Future<({String body, String? etag})?> Function({String? etag}) _fetch;
  final Future<({String body, String? etag})?> Function(String key) _read;
  final Future<void> Function(String key, {required String body, String? etag}) _store;

  /// The file as this build reads it, or null for a file it can't read.
  final T? Function(Object? json) _parse;

  /// A new [value] arrived.
  final void Function() _onChanged;
  final void Function(dynamic error, {dynamic stacktrace})? _onError;

  new({
    required this.key,
    required this._fetch,
    required this._read,
    required this._store,
    required this._parse,
    required this._onChanged,
    this._onError,
  });

  T? _value;
  Future<void>? _loading;

  /// The file, once read.
  T? get value => _value;

  /// Reads the file once a launch, however many places ask: the copy kept on
  /// the device first, then the CDN's, if it has a newer one. Nobody needs to
  /// await it: whatever arrives calls back.
  Future<void> ensure() => _loading ??= _load();

  Future<void> _load() async {
    String? etag;
    try {
      if (await _read(key) case (:final body, etag: final kept)) {
        if (_decode(body) case final T value) {
          _value = value;
          etag = kept;
          _onChanged();
        }
      }
    } catch (e, s) {
      _onError?.call(e, stacktrace: s);
    }

    final ({String body, String? etag})? fresh;
    try {
      fresh = await _fetch(etag: etag);
    } catch (_) {
      // offline, or not published yet: the copy kept, if any, stands — and a
      // file that isn't there yet is no error to report on every launch
      return;
    }
    if (fresh == null) return;

    final value = _decode(fresh.body);
    if (value == null) {
      _onError?.call(FormatException('not a readable $key'));
      return;
    }
    _value = value;
    _onChanged();
    try {
      await _store(key, body: fresh.body, etag: fresh.etag);
    } catch (e, s) {
      _onError?.call(e, stacktrace: s);
    }
  }

  T? _decode(String body) {
    try {
      return _parse(jsonDecode(body));
    } on FormatException {
      return null;
    }
  }
}
