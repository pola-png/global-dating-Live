import 'supabase_service.dart';

class AccountDeletionService {
  AccountDeletionService._();

  static Future<void> deleteCurrentUserData() async {
    final userId = await SessionStore.ensureUserId();
    if (userId != null) {
      // Deleting user profile from public.users
      await SupabaseService.client.from('users').delete().eq('id', userId);
    }
    SessionStore.clear();
  }
}
