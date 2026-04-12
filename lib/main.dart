import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'services/appwrite_service.dart';
import 'services/push_registration_service.dart';
import 'services/admob_service.dart';
import 'services/google_play_billing_service.dart';
import 'services/analytics_service.dart';
import 'theme/app_theme.dart';

import 'screens/age_gate_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/group_chat_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/individual_chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/manage_photos_screen.dart';
import 'screens/policy_screen.dart';
import 'screens/coin_purchase_screen.dart';
import 'screens/video_call_screen.dart';
import 'screens/fast_match_screen.dart';
import 'screens/get_android_app_screen.dart';
import 'screens/admin_support_screen.dart';
import 'services/realtime_notification_service.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Flutter Animate
  Animate.restartOnHotReload = true;

  if (!kIsWeb) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    // Set preferred orientations for mobile
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  
  try {
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
    if (!kIsWeb) {
      await AdMobService.initialize();
    }
    await GooglePlayBillingService.instance.init();
    AnalyticsService.instance; // Initialize analytics
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue without Firebase on web if it fails
  }

  // Check connectivity
  bool hasConnectivity = true;
  try {
    final connectivityResult = await Connectivity().checkConnectivity();
    hasConnectivity = !connectivityResult.contains(ConnectivityResult.none);
  } catch (e) {
    debugPrint('Connectivity check error: $e');
  }
  final prefs = await SharedPreferences.getInstance();
  final bool isOfAge = prefs.getBool('is_of_age') ?? false;

  // Check for existing session
  bool hasSession = false;
  try {
    await SessionStore.refresh();
    hasSession = SessionStore.userId != null;
  } catch (e) {
    debugPrint('Session check error: $e');
    hasSession = false;
  }

  runApp(MainApp(
    isOfAge: isOfAge, 
    hasSession: hasSession,
    hasConnectivity: hasConnectivity,
  ));
  
  if (!kIsWeb) {
    _startRealtimeNotifications();
    _initializePushNotifications();
  }
}

class MainApp extends StatelessWidget {
  final bool isOfAge;
  final bool hasSession;
  final bool hasConnectivity;

  const MainApp({
    super.key, 
    required this.isOfAge, 
    required this.hasSession,
    required this.hasConnectivity,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Global Dating Chat',
      navigatorKey: _navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: !hasConnectivity 
          ? '/offline' 
          : (!isOfAge ? '/age-gate' : (hasSession ? '/home' : '/login')),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        final overlay = brightness == Brightness.dark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.dark,
              );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: ScrollConfiguration(
            behavior: const _SmoothScrollBehavior(),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      routes: {
        '/age-gate': (context) => const AgeGateScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/groups': (context) => const GroupsScreen(),
        '/chat': (context) => const ChatListScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/profile/edit': (context) => const EditProfileScreen(),
        '/profile/photos': (context) => const ManagePhotosScreen(),
        '/policy': (context) => const PolicyScreen(),
        '/coins': (context) => const CoinPurchaseScreen(),
        '/video-call': (context) => const VideoCallScreen(),
        '/fast-match': (context) => const FastMatchScreen(),
        '/get-android-app': (context) => const GetAndroidAppScreen(),
        '/admin/support': (context) => const AdminSupportScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/groups/') == true) {
          final slug = settings.name!.split('/').last;
          final country = settings.arguments as Country?;
          if (country != null) {
            return MaterialPageRoute(
              builder: (context) => GroupChatScreen(
                countrySlug: slug,
                country: country,
              ),
            );
          }
        } else if (settings.name?.startsWith('/chat/') == true) {
          final chatRoomId = settings.name!.split('/').last;
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder: (context) => IndividualChatScreen(
                chatRoomId: chatRoomId,
                chatRoom: args['chatRoom'],
                otherUser: args['otherUser'],
              ),
            );
          }
        } else if (settings.name?.startsWith('/profile/') == true &&
            settings.name != '/profile/edit') {
          final userId = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: userId),
          );
        }
        // Fallback for unknown routes
        return MaterialPageRoute(
          builder: (context) => !isOfAge ? const AgeGateScreen() : (hasSession ? const HomeScreen() : const LoginScreen()),
        );
      },
    );
  }
}

// Start simple in-app realtime notifications once the widget tree is ready.
// This shows a small SnackBar when new messages are created while the app is open.
void _startRealtimeNotifications() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    RealtimeNotificationService.start(_navigatorKey);
  });
}

// Initialize push notifications for users who are already logged in
void _initializePushNotifications() {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Wait a bit for the app to fully initialize
    await Future.delayed(const Duration(seconds: 2));
    
    // Check if user is already logged in and register for push
    final userId = await SessionStore.ensureUserId();
    if (userId != null) {
      PushRegistrationService.forceRegister();
    }
  });
}

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
