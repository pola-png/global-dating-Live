import 'package:appwrite/appwrite.dart';

import '../config/appwrite_config.dart';

class AppwriteService {
  static final Client client = Client()
    ..setEndpoint(AppwriteConfig.endpoint)
    ..setProject(AppwriteConfig.projectId);

  static final Account account = Account(client);
  static final Databases databases = Databases(client);
  static final Storage storage = Storage(client);
  static final Realtime realtime = Realtime(client);
  static final Messaging messaging = Messaging(client);
  static final Functions functions = Functions(client);
}

class SessionStore {
  static String? _userId;

  static String? get userId => _userId;

  static Future<String?> ensureUserId() async {
    if (_userId != null) return _userId;
    
    try {
      final user = await AppwriteService.account.get();
      _userId = user.$id;
      return _userId;
    } catch (_) {
      return null;
    }
  }

  static void setUserId(String? id) {
    _userId = id;
  }

  static Future<void> refresh() async {
    try {
      final user = await AppwriteService.account.get();
      _userId = user.$id;
    } catch (_) {
      _userId = null;
    }
  }

  static void clear() {
    _userId = null;
  }
}
