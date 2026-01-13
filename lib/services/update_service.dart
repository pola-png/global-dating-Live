import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/appwrite_config.dart';
import 'appwrite_service.dart';

class UpdateService {
  static const String _lastCheckKey = 'last_update_check';

  static Future<void> checkForUpdates(BuildContext context, {bool showNoUpdateDialog = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.parse(packageInfo.buildNumber);
      
      // Reset notification flag if app was updated
      final lastKnownBuild = prefs.getInt('last_known_build') ?? 0;
      if (currentBuildNumber > lastKnownBuild) {
        await prefs.setBool('update_notification_shown', false);
        await prefs.setInt('last_known_build', currentBuildNumber);
      }
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      
      // Check only once per day unless forced
      if (!showNoUpdateDialog && now - lastCheck < 86400000) return;
      
      // Get simple update toggle from Appwrite
      final updateDoc = await AppwriteService.databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'app_updates',
        documentId: 'current_update',
      );
      
      final updateEnabled = updateDoc.data['enabled'] as bool? ?? false;
      final updateShown = prefs.getBool('update_notification_shown') ?? false;
      
      await prefs.setInt(_lastCheckKey, now);
      
      if (updateEnabled && !updateShown && context.mounted) {
        final downloadUrl = updateDoc.data['downloadUrl'] as String? ?? 'https://globaldatingchat.com/downloads/app-latest.apk';
        final releaseNotes = updateDoc.data['releaseNotes'] as String? ?? 'New version available!';
        
        _showUpdateDialog(context, downloadUrl, releaseNotes);
        await prefs.setBool('update_notification_shown', true);
      } else if (showNoUpdateDialog && context.mounted) {
        _showNoUpdateDialog(context);
      }
    } catch (e) {
      if (showNoUpdateDialog && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to check for updates')),
        );
      }
    }
  }

  static void _showUpdateDialog(BuildContext context, String downloadUrl, String releaseNotes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A new version is available!'),
            if (releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('What\'s New:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(releaseNotes),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse(downloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  static void _showNoUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Updates'),
        content: const Text('You are using the latest version of the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}