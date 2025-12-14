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
}

class SessionStore {
  static String? _userId;

  static String? get userId => _userId;

  static Future<String?> ensureUserId() async {
    // Do not hit the network automatically.
    // Until login/registration explicitly sets the user ID,
    // treat the visitor as a guest.
    return _userId;
  }

  static void setUserId(String? id) {
    _userId = id;
  }

  static Future<void> refresh() async {
    // No automatic network call here; left as a no-op for now.
  }

  static void clear() {
    _userId = null;
  }
}
