import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../services/supabase_service.dart';
import '../services/admob_service.dart';
import '../services/google_play_billing_service.dart';
import '../services/subscription_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    try {
      // Step 1: Initialize core Supabase service with a fast 2-second timeout
      try {
        await SupabaseService.initialize().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('Supabase init timed out - proceeding to screen');
          },
        );
      } catch (e) {
        debugPrint('Supabase init error: $e');
      }

      // Step 2: Fire platform services asynchronously in the background (non-blocking)
      _initBackgroundServices();

      // Step 3: Fast local preferences check
      final prefs = await SharedPreferences.getInstance();
      final bool isOfAge = prefs.getBool('is_of_age') ?? false;
      final bool isLogged = prefs.getBool('is_user_logged_in') ?? false;

      if (!mounted) return;

      // Navigate to correct starting screen instantly (under 300ms)
      if (!isOfAge) {
        Navigator.pushReplacementNamed(context, '/age-gate');
      } else if (isLogged) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/age-gate');
      }
    }
  }

  void _initBackgroundServices() {
    Future.microtask(() async {
      try {
        await _initFirebase().timeout(const Duration(seconds: 3));
      } catch (_) {}
      try {
        await _initAdmob().timeout(const Duration(seconds: 3));
      } catch (_) {}
      try {
        await GooglePlayBillingService.instance.init().timeout(const Duration(seconds: 3));
      } catch (_) {}
      try {
        await SubscriptionService.init().timeout(const Duration(seconds: 3));
      } catch (_) {}
    });
  }

  Future<void> _initFirebase() async {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDGqL7rZxJ5Zx5Zx5Zx5Zx5Zx5Zx5Zx5Z",
          authDomain: "globaldatingchat.firebaseapp.com",
          projectId: "globaldatingchat",
          storageBucket: "globaldatingchat.appspot.com",
          messagingSenderId: "123456789",
          appId: "1:123456789:web:abcdef123456789",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  }

  Future<void> _initAdmob() async {
    if (!kIsWeb) {
      await AdMobService.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icon/app_icon.png',
              width: 96,
              height: 96,
              errorBuilder: (_, __, ___) => Icon(
                Icons.favorite_rounded,
                size: 80,
                color: colorScheme.primary,
              ),
            )
            .animate()
            .scale(duration: 400.ms, curve: Curves.easeOutBack)
            .fadeIn(duration: 400.ms),
            const SizedBox(height: 20),
            Text(
              'Dating Connect',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
                letterSpacing: 0.8,
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms)
            .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
            const SizedBox(height: 36),
            // Subdued indicator
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
