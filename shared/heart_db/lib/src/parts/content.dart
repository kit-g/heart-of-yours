part of '../../heart_db.dart';

/// Static content files kept between launches (heart-of-yours#352), by the
/// path they are served at.
mixin _Content on _LocalDatabase {
  /// The copy of [key] last stored, or null for none.
  Future<({String body, String? etag})?> getContent(String key) async {
    final rows = await _db.query(_content, columns: ['body', 'etag'], where: 'key = ?', whereArgs: [key]);
    return switch (rows) {
      [{'body': final String body, 'etag': final String? etag}] => (body: body, etag: etag),
      _ => null,
    };
  }

  /// Keeps [body] as the copy of [key], replacing the one before.
  Future<void> storeContent(String key, {required String body, String? etag}) async {
    await _db.insert(
      _content,
      {'key': key, 'body': body, 'etag': etag, 'stored_at': DateTime.timestamp().toIso8601String()},
      conflictAlgorithm: .replace,
    );
  }
}
