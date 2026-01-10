import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_config.dart';
import 'appwrite_service.dart';

class WalletService {
  static const _prefsKey = 'wallet_coin_balance';

  static Future<int> getBalance() async {
    final userId = await SessionStore.ensureUserId();
    if (userId == null) return _getLocalBalance();

    try {
      final doc = await AppwriteService.databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
      );
      final data = doc.data;
      final balance = (data['coinBalance'] ?? 0) as int;
      await _setLocalBalance(balance);
      return balance;
    } catch (_) {
      return _getLocalBalance();
    }
  }

  static Future<bool> addCoins(int amount) async {
    if (amount <= 0) return false;

    final userId = await SessionStore.ensureUserId();
    if (userId == null) return _addLocal(amount);

    try {
      final currentBalance = await getBalance();
      final newBalance = currentBalance + amount;

      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
        data: {'coinBalance': newBalance},
      );

      await _setLocalBalance(newBalance);
      return true;
    } catch (_) {
      return _addLocal(amount);
    }
  }

  static Future<bool> spendCoins(int amount) async {
    if (amount <= 0) return false;

    final current = await getBalance();
    if (current < amount) return false;

    final userId = await SessionStore.ensureUserId();
    if (userId == null) return _spendLocal(amount);

    try {
      final newBalance = current - amount;

      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
        data: {'coinBalance': newBalance},
      );

      await _setLocalBalance(newBalance);
      return true;
    } catch (_) {
      return _spendLocal(amount);
    }
  }

  static Future<int> _getLocalBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKey) ?? 0;
  }

  static Future<void> _setLocalBalance(int balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, balance);
  }

  static Future<bool> _addLocal(int amount) async {
    final current = await _getLocalBalance();
    await _setLocalBalance(current + amount);
    return true;
  }

  static Future<bool> _spendLocal(int amount) async {
    final current = await _getLocalBalance();
    if (current < amount) return false;
    await _setLocalBalance(current - amount);
    return true;
  }
}
