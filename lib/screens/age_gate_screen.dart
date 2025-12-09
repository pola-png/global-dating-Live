import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class AgeGateScreen extends StatelessWidget {
  const AgeGateScreen({super.key});

  Future<void> _handleAgeConfirmation(BuildContext context, bool isOver18) async {
    if (isOver18) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_of_age', true);
      if (!context.mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Age Restriction'),
            content: const Text('You must be 18 years or older to use this app.'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  SystemChannels.platform.invokeMethod('System.exit', 0);
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Age Verification',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'You must be 18 years or older to use this app. Please confirm your age.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => _handleAgeConfirmation(context, true),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('I am 18 or older'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _handleAgeConfirmation(context, false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('I am under 18'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
