/// A failure in the native library, with a [code] a caller can branch on.
///
/// The codes: `bad_input`, `wrong_storage_key` (state sealed under another
/// key), `not_text`, `session_failed`, `not_first_message`, `encrypt_failed`,
/// `decrypt_failed`, `not_known` (a thread key that doesn't reach back that
/// far), `no_comparison`, `comparison_state`, `comparison_failed`,
/// `wont_open` (a note), `not_franked`, `commitment_mismatch`, `unknown_op`.
final class SealboxException implements Exception {
  const new(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'SealboxException($code): $message';
}
