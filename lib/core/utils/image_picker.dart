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

Future<LocalImage?> cropImage(BuildContext context, LocalFile file) async {
  final cropped = await _cropper.cropImage(
    sourcePath: file.$2,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Cropper',
        toolbarColor: Colors.deepOrange,
        toolbarWidgetColor: Colors.white,
        aspectRatioPresets: [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.square,
        ],
      ),
      IOSUiSettings(
        title: 'Cropper',
        aspectRatioPresets: [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.square,
        ],
      ),
      WebUiSettings(
        context: context,
      ),
    ],
  );
  return switch (cropped) {
    CroppedFile f => (await f.readAsBytes(), mimeType: file.$1.mimeType, name: file.$1.name),
    null => null,
  };
}

Future<LocalImage?> pickAndCropGalleryImage(BuildContext context) async {
  return pickGalleryImage().then<LocalImage?>(
    (image) {
      if (image == null) return null;
      if (!context.mounted) return null;
      return cropImage(context, image);
    },
  );
}

Future<LocalImage?> captureAndCropPhoto(BuildContext context) async {
  return capturePhoto().then<LocalImage?>(
    (image) {
      if (image == null) return null;
      if (!context.mounted) return null;
      return cropImage(context, image);
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
