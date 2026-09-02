import 'package:flutter/material.dart';

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy & Terms'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Age Requirement',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You must be at least 18 years old to use this service. By using this app, you confirm that you are 18 years of age or older.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We collect and store your profile information, messages, photos, live activity, and basic usage data to provide our dating service. Data is stored securely and may be shared only when needed to run the app, such as Google AdMob.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Data We Collect:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Profile information (name, age, location)\n'
              '• Photos you upload\n'
              '• Messages and posts\n'
              '• Live stream and video call activity\n'
              '• Usage data and preferences',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              'Child Safety & CSAE Policy',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dating Connect / Global Dating Chat (developer: Digiskills Consult) strictly prohibits Child Sexual Abuse and Exploitation (CSAE) and Child Sexual Abuse Material (CSAM). Any user engaging in or uploading CSAE/CSAM content will be immediately banned and reported to legal authorities and NCMEC.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              'Terms of Service',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'By using this app, you agree to:\n\n'
              '• Be respectful to other users\n'
              '• Not post inappropriate content\n'
              '• Not harass or abuse other users\n'
              '• Provide accurate information\n'
              '• Not use the service for illegal activities\n\n'
              'Violation of these terms may result in account suspension or termination.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              'Account Deletion',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can delete your account at any time from your profile settings. This triggers removal of your account and associated data from our systems subject to legal and safety retention needs.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              'Contact',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'For questions or concerns about privacy, please contact us at ubongp.udoka@gmail.com',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
