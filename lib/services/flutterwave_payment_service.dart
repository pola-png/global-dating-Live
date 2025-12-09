import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/flutterwave_config.dart';
import 'appwrite_service.dart';

class FlutterwavePaymentService {
  static Future<bool> payForCoins({
    required BuildContext context,
    required int coins,
    required int price,
  }) async {
    final userId = await SessionStore.ensureUserId();
    if (userId == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return false;
    }

    final link = FlutterwaveConfig.hostedPaymentLinks[coins];
    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No Flutterwave payment link configured for $coins coins.\n'
            'Add one in FlutterwaveConfig.hostedPaymentLinks.',
          ),
        ),
      );
      return false;
    }

    final uri = Uri.parse(link);

    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open payment page.')),
      );
      return false;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch Flutterwave payment.')),
      );
      return false;
    }

    return true;
  }

  static Future<bool> payForFastMatch({
    required BuildContext context,
  }) async {
    final userId = await SessionStore.ensureUserId();
    if (userId == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return false;
    }

    final link = FlutterwaveConfig.fastMatchPaymentLink;
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fast match payment link is not configured.\nAdd it in FlutterwaveConfig.fastMatchPaymentLink.',
          ),
        ),
      );
      return false;
    }

    final uri = Uri.parse(link);

    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open payment page.')),
      );
      return false;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch Flutterwave payment.')),
      );
      return false;
    }

    return true;
  }
}
