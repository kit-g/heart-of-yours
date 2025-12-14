import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

final _picker = ImagePicker();
final _cropper = ImageCropper();

typedef LocalImage = (Uint8List, {String? mimeType, String? name});
typedef LocalFile = (LocalImage, String path);

Future<LocalFile?> pickGalleryImage() async {
  final image = await _picker.pickImage(source: ImageSource.gallery);
  return image.toLocalFile();
}

Future<LocalFile?> capturePhoto() async {
  final photo = await _picker.pickImage(source: ImageSource.camera);
  return photo.toLocalFile();
}

Future<LocalImage?> cropImage(BuildContext context, LocalFile file, String header) async {
  final ThemeData(:appBarTheme, :scaffoldBackgroundColor, :colorScheme, :platform) = Theme.of(context);
  final aspectRatioPresets = const <CropAspectRatioPreset>[.original, .square];
  final cropped = await _cropper.cropImage(
    sourcePath: file.$2,
    uiSettings: [
      if (platform == .android)
        AndroidUiSettings(
          toolbarTitle: header,
          toolbarColor: colorScheme.surface,
          toolbarWidgetColor: colorScheme.onSurface,
          backgroundColor: scaffoldBackgroundColor,
          cropFrameColor: colorScheme.tertiaryContainer,
          cropGridColor: colorScheme.tertiary,
          cropStyle: CropStyle.rectangle,
          dimmedLayerColor: colorScheme.primaryContainer.withValues(alpha: .3),
          aspectRatioPresets: aspectRatioPresets,
        ),
      if (platform == .iOS)
        IOSUiSettings(
          title: header,
          aspectRatioPresets: aspectRatioPresets,
        ),
      if (kIsWeb) WebUiSettings(context: context),
    ],
  );
  return switch (cropped) {
    CroppedFile f => (await f.readAsBytes(), mimeType: file.$1.mimeType, name: file.$1.name),
    null => null,
  };
}

Future<LocalImage?> pickAndCropGalleryImage(BuildContext context, String copy) {
  return pickGalleryImage().then<LocalImage?>(
    (image) {
      if (image == null) return null;
      if (!context.mounted) return null;
      return switch (Theme.of(context).platform) {
        .android => cropImage(context, image, copy),
        .iOS => cropImage(context, image, copy),
        .macOS => image.$1,
        _ => null,
      };
    },
  );
}

Future<LocalImage?> captureAndCropPhoto(BuildContext context, String copy) {
  return capturePhoto().then<LocalImage?>(
    (image) {
      if (image == null) return null;
      if (!context.mounted) return null;

      return switch (Theme.of(context).platform) {
        .android => cropImage(context, image, copy),
        .iOS => cropImage(context, image, copy),
        .macOS => image.$1,
        _ => null,
      };
    },
  );
}

extension on XFile {
  Future<LocalImage> toLocalImage({String? mimeType}) async {
    return (await readAsBytes(), mimeType: mimeType ?? this.mimeType, name: name);
  }
}

extension on XFile? {
  Future<LocalFile?> toLocalFile() async {
    return switch (this) {
      XFile f => (await f.toLocalImage(mimeType: lookupMimeType(f.path)), f.path),
      _ => null,
    };
  }
}

extension SupportsPhoto on BuildContext {
  bool supportsTakingPhoto() {
    final platform = Theme.of(this).platform;
    return <TargetPlatform>[.iOS, .android].contains(platform);
  }
}
