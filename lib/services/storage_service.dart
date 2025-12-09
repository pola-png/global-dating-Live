import 'package:appwrite/appwrite.dart';
import 'package:image_picker/image_picker.dart';

import '../config/appwrite_config.dart';
import 'appwrite_service.dart';

class StorageService {
  static String buildFileUrl(String fileId) {
    // Support endpoints with or without `/v1` and trailing slash.
    var base = AppwriteConfig.endpoint.trim();
    // Remove trailing slashes
    base = base.replaceFirst(RegExp(r'/+$'), '');
    // Ensure we have `/v1` at the end
    if (!base.endsWith('/v1')) {
      base = '$base/v1';
    }
    return '$base/storage/buckets/${AppwriteConfig.mediaBucketId}/files/$fileId/view?project=${AppwriteConfig.projectId}';
  }

  static Future<String?> uploadAvatar(String userId, XFile imageFile) async {
    try {
      final extension = _inferExtension(imageFile);
      final bytes = await imageFile.readAsBytes();

      final file = await AppwriteService.storage.createFile(
        bucketId: AppwriteConfig.mediaBucketId,
        fileId: ID.unique(),
        file: InputFile.fromBytes(
          bytes: bytes,
          filename: '$userId-avatar-${DateTime.now().millisecondsSinceEpoch}.$extension',
        ),
      );

      return file.$id;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> uploadPhoto(String userId, XFile imageFile) async {
    try {
      final extension = _inferExtension(imageFile);
      final bytes = await imageFile.readAsBytes();

      final file = await AppwriteService.storage.createFile(
        bucketId: AppwriteConfig.mediaBucketId,
        fileId: ID.unique(),
        file: InputFile.fromBytes(
          bytes: bytes,
          filename: '$userId-photo-${DateTime.now().millisecondsSinceEpoch}.$extension',
        ),
      );

      return file.$id;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> deletePhoto(String fileId) async {
    try {
      await AppwriteService.storage.deleteFile(
        bucketId: AppwriteConfig.mediaBucketId,
        fileId: fileId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static String getAvatarUrl(String? avatarPath, String avatarLetter) {
    if (avatarPath != null && avatarPath.isNotEmpty) {
      return buildFileUrl(avatarPath);
    }
    return 'https://ui-avatars.com/api/?name=$avatarLetter&background=9400D3&color=fff&size=200';
  }

  static String _inferExtension(XFile file) {
    final name = file.name.toLowerCase();
    final path = file.path.toLowerCase();
    if (name.contains('.')) return name.split('.').last;
    if (path.contains('.')) return path.split('.').last;
    return 'jpg';
  }
}
