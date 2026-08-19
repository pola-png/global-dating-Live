import 'package:image_picker/image_picker.dart';
import 'supabase_service.dart';

class StorageService {
  static String buildFileUrl(String fileId) {
    if (fileId.startsWith('http')) return fileId;
    return SupabaseService.client.storage.from('photos').getPublicUrl(fileId);
  }

  static Future<String?> uploadAvatar(String userId, XFile imageFile) async {
    try {
      final extension = _inferExtension(imageFile);
      final bytes = await imageFile.readAsBytes();
      final path = '$userId-avatar-${DateTime.now().millisecondsSinceEpoch}.$extension';

      await SupabaseService.client.storage.from('avatars').uploadBinary(path, bytes);
      return path;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> uploadPhoto(String userId, XFile imageFile) async {
    try {
      final extension = _inferExtension(imageFile);
      final bytes = await imageFile.readAsBytes();
      final path = '$userId-photo-${DateTime.now().millisecondsSinceEpoch}.$extension';

      await SupabaseService.client.storage.from('photos').uploadBinary(path, bytes);
      return path;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> deletePhoto(String fileId) async {
    try {
      await SupabaseService.client.storage.from('photos').remove([fileId]);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String getAvatarUrl(String? avatarPath, String avatarLetter) {
    if (avatarPath != null && avatarPath.isNotEmpty) {
      if (avatarPath.startsWith('http')) return avatarPath;
      return SupabaseService.client.storage.from('avatars').getPublicUrl(avatarPath);
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
