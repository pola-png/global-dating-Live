import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/appwrite_service.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final prefs = await SharedPreferences.getInstance();
  final bool isOfAge = prefs.getBool('is_of_age') ?? false;

  runApp(MainApp(isOfAge: isOfAge));

  // Optionally refresh session in the background (non-blocking).
  // This will set SessionStore.userId if a valid session cookie exists.
  // ignore: discarded_futures
  SessionStore.refresh();
}

class MainApp extends StatelessWidget {
  final bool isOfAge;

  const MainApp({super.key, required this.isOfAge});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Global Dating Chat',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: isOfAge ? '/home' : '/age-gate',
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
        return null;
      },
    );
  }
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
