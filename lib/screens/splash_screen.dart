import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
    final startTime = DateTime.now();

    try {
      // Step 1: Run core platform initializations in parallel
      await Future.wait([
        _initFirebase(),
        _initAdmob(),
        GooglePlayBillingService.instance.init(),
        SupabaseService.initialize(),
      ]);

      // Initialize subscriptions after Supabase is ready
      await SubscriptionService.init();

      // Check connectivity and preferences
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnectivity = !connectivityResult.contains(ConnectivityResult.none);
      
      final prefs = await SharedPreferences.getInstance();
      final bool isOfAge = prefs.getBool('is_of_age') ?? false;
      final hasSession = await SessionStore.isUserLoggedInLocally();

      // Ensure splash screen displays for at least 1.0 second for branding animation
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inMilliseconds < 1000) {
        await Future.delayed(Duration(milliseconds: 1000 - elapsed.inMilliseconds));
      }

      if (!mounted) return;

      // Navigate to correct starting screen
      if (!hasConnectivity) {
        Navigator.pushReplacementNamed(context, '/offline');
      } else if (!isOfAge) {
        Navigator.pushReplacementNamed(context, '/age-gate');
      } else if (hasSession) {
        if (SubscriptionService.hasActiveSubscription) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/paywall');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      // Fail-safe redirect to login
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
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
            // Pulsing heart logo
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.heart,
                color: colorScheme.primary,
                size: 72,
              ),
            )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.1, 1.1),
              duration: 800.ms,
              curve: Curves.easeInOut,
            ),
            const SizedBox(height: 32),
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
            const SizedBox(height: 48),
            // Subdued indicator
            SizedBox(
              width: 40,
              height: 40,
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
