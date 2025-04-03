import 'dart:typed_data';

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
  final ThemeData(:appBarTheme, :scaffoldBackgroundColor, :colorScheme) = Theme.of(context);

  final cropped = await _cropper.cropImage(
    sourcePath: file.$2,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: header,
        toolbarColor: colorScheme.surface,
        toolbarWidgetColor: colorScheme.onSurface,
        backgroundColor: scaffoldBackgroundColor,
        cropFrameColor: colorScheme.tertiaryContainer,
        cropGridColor: colorScheme.tertiary,
        cropStyle: CropStyle.rectangle,
        dimmedLayerColor: colorScheme.primaryContainer.withValues(alpha: .3),
        aspectRatioPresets: const [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.square,
        ],
      ),
      IOSUiSettings(
        title: header,
        aspectRatioPresets: const [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.square,
        ],
      ),
      WebUiSettings(context: context),
    ],
  );
  return switch (cropped) {
    CroppedFile f => (await f.readAsBytes(), mimeType: file.$1.mimeType, name: file.$1.name),
    null => null,
  };
}

Future<LocalImage?> pickAndCropGalleryImage(BuildContext context, String copy) async {
  return pickGalleryImage().then<LocalImage?>(
    (image) {
      if (image == null) return null;
      if (!context.mounted) return null;
      return cropImage(context, image, copy);
    },
  );
}

Future<LocalImage?> captureAndCropPhoto(BuildContext context, String copy) async {
  return capturePhoto().then<LocalImage?>(
    (image) {
      if (image == null) return null;
      if (!context.mounted) return null;
      return cropImage(context, image, copy);
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
