import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  Future<void> _openWebStandards() async {
    final Uri url = Uri.parse('https://global-dating-live-three.vercel.app/child-safety-standards.html');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Safety Standards'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dating Connect Policy Declaration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Developer: Digiskills Consult\nApplication: Dating Connect (datingconnect.app)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Age Requirement (18+ Adult-Only)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dating Connect is strictly an adult-only (18+) service. Minors are barred from registering or accessing any feature of this application.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 24),

            const Text(
              'Child Safety Standards & CSAE Zero-Tolerance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dating Connect by Digiskills Consult enforces an absolute zero-tolerance policy against Child Sexual Abuse Material (CSAM) and Child Sexual Abuse and Exploitation (CSAE).\n\n'
              '• Creation, upload, request, or sharing of CSAE content is strictly prohibited.\n'
              '• Grooming, extortion, harassment, or solicitation of minors is strictly prohibited.\n'
              '• Detected violations trigger an immediate permanent account ban, legal evidence preservation, and direct reporting to NCMEC CyberTipline and law enforcement.\n'
              '• Users can report any profile, message, photo, or live stream instantly using in-app report buttons or emailing our dedicated officer.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _openWebStandards,
              icon: const Icon(Icons.launch, size: 18),
              label: const Text('View Published Child Safety Standards Page'),
            ),
            const SizedBox(height: 24),

            const Text(
              'Privacy Policy & Data Handling',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We collect profile information, uploaded photos, chat records, and basic device metrics strictly to deliver the service, moderate content, and display Google AdMob ads. Data is never sold.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 24),

            const Text(
              'Account & Data Deletion',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can request account deletion directly from your profile settings or by contacting our team. Account data is purged subject to legal retention obligations.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 24),

            const Text(
              'Child Safety Contact Officer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lead Officer: Child Safety Review Officer\n'
              'Department: Digiskills Consult Safety & Moderation Department\n'
              'Email: ubongp.udoka@gmail.com',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
