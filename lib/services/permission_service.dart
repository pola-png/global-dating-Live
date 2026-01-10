import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<void> requestAllPermissions(BuildContext context) async {
    final permissions = [
      Permission.notification,
      Permission.camera,
      Permission.microphone,
    ];

    final statuses = await permissions.request();
    
    final denied = statuses.entries
        .where((entry) => entry.value.isDenied || entry.value.isPermanentlyDenied)
        .map((entry) => entry.key)
        .toList();

    if (denied.isNotEmpty && context.mounted) {
      _showPermissionDialog(context, denied);
    }
  }

  static void _showPermissionDialog(BuildContext context, List<Permission> denied) {
    final permissionNames = denied.map((p) {
      switch (p) {
        case Permission.notification:
          return 'Notifications';
        case Permission.camera:
          return 'Camera';
        case Permission.microphone:
          return 'Microphone';
        default:
          return p.toString();
      }
    }).join(', ');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: Text(
          'Please enable $permissionNames permissions in Settings to use all app features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }
}
