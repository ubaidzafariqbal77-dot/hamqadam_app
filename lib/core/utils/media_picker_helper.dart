import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_constants.dart';
import '../validators/app_validators.dart';

/// A picked media file plus lightweight metadata used for client validation.
class PickedMedia {
  const PickedMedia({required this.path, required this.name, required this.sizeBytes});

  final String path;
  final String name;
  final int sizeBytes;

  String get extension => name.contains('.') ? name.split('.').last.toLowerCase() : '';
}

/// Validation outcome for a picked file.
class MediaValidation {
  const MediaValidation({this.error});
  final String? error;
  bool get isValid => error == null;
}

/// Wraps image_picker (images/video) and file_picker (audio/multi) so views
/// never touch the picker packages directly. Permissions are requested by the
/// underlying plugins only when a picker is actually invoked.
class MediaPickerHelper {
  MediaPickerHelper({ImagePicker? imagePicker}) : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  /// [highRes] keeps more detail for document scans. A CNIC number is small
  /// print — at 1600px/q85 the digits soften enough for OCR to miss them.
  /// Deliberately capped rather than full-size: the originals off a modern
  /// phone camera routinely exceed the 5 MB the app and the API both enforce.
  Future<PickedMedia?> pickImage({
    bool fromCamera = false,
    bool highRes = false,
  }) async {
    final XFile? file = await _imagePicker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: highRes ? 95 : 85,
      maxWidth: highRes ? 2400 : 1600,
    );
    return _wrap(file?.path);
  }

  Future<List<PickedMedia>> pickMultiImage({int max = AppConstants.maxGalleryImages}) async {
    final List<XFile> files = await _imagePicker.pickMultiImage(imageQuality: 85);
    final List<PickedMedia> result = <PickedMedia>[];
    for (final XFile f in files.take(max)) {
      final PickedMedia? m = await _wrap(f.path);
      if (m != null) result.add(m);
    }
    return result;
  }

  Future<PickedMedia?> pickVideo({bool fromCamera = false}) async {
    final XFile? file = await _imagePicker.pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    return _wrap(file?.path);
  }

  Future<PickedMedia?> pickAudio() async {
    // file_picker 12 replaced `FilePicker.platform.pickFiles` with a static
    // `pickFile` that returns the single file directly.
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: AppConstants.allowedAudioExt,
    );
    return _wrap(file?.path);
  }

  Future<PickedMedia?> _wrap(String? path) async {
    if (path == null || path.isEmpty) return null;
    final File file = File(path);
    final int size = await file.length();
    return PickedMedia(path: path, name: path.split(Platform.pathSeparator).last, sizeBytes: size);
  }

  // ---- Validation helpers ---------------------------------------------------

  static MediaValidation validateImage(PickedMedia media) =>
      _validate(media, AppConstants.allowedImageExt, AppConstants.maxImageBytes, 'Image');

  static MediaValidation validateVideo(PickedMedia media) =>
      _validate(media, AppConstants.allowedVideoExt, AppConstants.maxVideoBytes, 'Video');

  static MediaValidation validateAudio(PickedMedia media) =>
      _validate(media, AppConstants.allowedAudioExt, AppConstants.maxAudioBytes, 'Audio');

  static MediaValidation _validate(
    PickedMedia media,
    List<String> exts,
    int maxBytes,
    String label,
  ) {
    final String? extError = AppValidators.fileExtension(media.name, exts, field: label);
    if (extError != null) return MediaValidation(error: extError);
    final String? sizeError = AppValidators.fileSize(media.sizeBytes, maxBytes, field: label);
    if (sizeError != null) return MediaValidation(error: sizeError);
    return const MediaValidation();
  }
}
