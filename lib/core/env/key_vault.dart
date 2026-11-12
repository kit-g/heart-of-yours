import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:heart_state/heart_state.dart';

/// Where this device keeps its encryption keys (#555): the Keychain on iOS,
/// the Keystore on Android.
///
/// On this device only. The Keychain's this-device-only class never reaches an
/// iCloud backup or a new iPhone, and isn't synced. On Android the store's own
/// key lives in the Keystore, which no backup carries, and its preferences file
/// is excluded from backup and device transfer (`backup_rules.xml`,
/// `data_extraction_rules.xml`); a copy that comes back anyway can't be read,
/// and is reset. Either way a restored phone starts as a new device, which is
/// what the design asks: one restored from an old backup would reuse keys it
/// had already used.
class SecureKeyVault implements KeyVault {
  const new();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: .first_unlock_this_device, synchronizable: false),
    aOptions: AndroidOptions(resetOnError: true),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
