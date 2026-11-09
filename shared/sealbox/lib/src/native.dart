import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'exception.dart';

@Native<Pointer<Utf8> Function(Pointer<Utf8>)>(symbol: 'sealbox_call')
external Pointer<Utf8> _call(Pointer<Utf8> input);

@Native<Void Function(Pointer<Utf8>)>(symbol: 'sealbox_free')
external void _free(Pointer<Utf8> output);

/// One operation in the native library: [op] and its arguments go in as JSON,
/// and the answer comes back as JSON, or as a [SealboxException].
Map<String, Object?> call(String op, [Map<String, Object?> arguments = const {}]) {
  final input = jsonEncode({...arguments, 'op': op}).toNativeUtf8();
  try {
    final output = _call(input);
    try {
      return switch (jsonDecode(output.toDartString())) {
        {'error': {'code': final String code, 'message': final String message}} => throw SealboxException(
          code,
          message,
        ),
        final Map<String, Object?> answer => answer,
        final other => throw SealboxException('bad_output', 'not an object: $other'),
      };
    } finally {
      _free(output);
    }
  } finally {
    malloc.free(input);
  }
}
