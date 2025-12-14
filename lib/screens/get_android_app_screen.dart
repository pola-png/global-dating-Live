import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Configure this with your Appwrite APK download URL.
const String kAndroidApkDownloadUrl = '';

class GetAndroidAppScreen extends StatelessWidget {
  const GetAndroidAppScreen({super.key});

  bool get _isAndroidDevice {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  Future<void> _downloadApk(BuildContext context) async {
    if (kAndroidApkDownloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Android APK download link is not configured yet.',
          ),
        ),
      );
      return;
    }

    final uri = Uri.parse(kAndroidApkDownloadUrl);

    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open Android app download link.'),
        ),
      );
      return;
    }

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isAndroidDevice) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Get the Android App'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This page is only for Android phones.\n\n'
              'Please open https://www.globaldatingchat.online on your Android device '
              'to download the Android app directly.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get the Android App'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Install Global Dating for Android',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Download the official Android app directly from our server. '
                'After download, tap the APK file and follow the on-screen steps '
                'to complete installation.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _downloadApk(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Download Android APK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

