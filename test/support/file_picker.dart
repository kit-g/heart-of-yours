import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The platform file picker, answering every pick with [file] — or with
/// nothing, the user backing out, when it is null.
class FakePicker extends FileSelectorPlatform with MockPlatformInterfaceMixin {
  final XFile? file;

  new(this.file);

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    return file;
  }
}
