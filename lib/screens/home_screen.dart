import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../components/responsive_page.dart';
import '../services/supabase_service.dart';
import '../services/admob_service.dart';
import '../services/subscription_service.dart';
import '../services/storage_service.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _profiles = [];
  Map<String, dynamic>? _currentUserProfile;
  bool _isFetching = false;
  bool _fetchCompleted = false;
  BannerAd? _bannerAd;
  bool _adLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCachedProfiles().then((_) {
      _initDiscovery();
    });
    if (!kIsWeb && SubscriptionService.shouldShowGeneralAds) {
      _loadBannerAd();
    }
  }

  Future<void> _loadCachedProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_profiles');
      if (cachedData != null) {
        final List<dynamic> decoded = json.decode(cachedData);
        if (mounted) {
          setState(() {
            _profiles = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      }
    } catch (_) {}
  }

  void _loadBannerAd() {
    _bannerAd = AdMobService.createBannerAd()
      ..load().then((_) {
        if (mounted) {
          setState(() {
            _adLoaded = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _initDiscovery() async {
    final userId = await SessionStore.ensureUserId();
    if (!mounted) return;
    if (userId == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if (!SubscriptionService.hasActiveSubscription) {
      Navigator.pushReplacementNamed(context, '/paywall');
      return;
    }

    await _fetchCurrentUserProfile();
    await _refreshProfiles();
  }

  Future<void> _fetchCurrentUserProfile() async {
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId != null) {
        final doc = await SupabaseService.client
            .from('users')
            .select('*')
            .eq('id', userId)
            .maybeSingle();
        if (doc != null) {
          _currentUserProfile = {
            ...doc,
            'id': doc['id'],
            'fullName': doc['full_name'],
            'lookingFor': doc['looking_for'],
            'country': doc['country'],
            'city': doc['city'],
            'age': doc['age'],
          };
        }
      }
    } catch (e) {
      debugPrint('Error fetching current user profile: $e');
    }
  }

  Future<void> _refreshProfiles() async {
    if (mounted) {
      setState(() {
        _isFetching = true;
        _fetchCompleted = false;
      });
    }

    try {
      final currentUserId = await SessionStore.ensureUserId();
      final res = await SupabaseService.client
          .from('users')
          .select('*')
          .limit(50);

      final list = res.map((row) => {
        'id': row['id'],
        'userId': row['id'],
        'fullName': row['full_name'],
        'email': row['email'],
        'age': row['age'],
        'country': row['country'],
        'city': row['city'],
        'lookingFor': row['looking_for'],
        'relationshipStatus': row['relationship_status'],
        'about': row['about'],
        'avatarLetter': row['avatar_letter'],
        'photos': row['photos'] != null ? List<String>.from(row['photos']) : [],
        'joinedGroups': row['joined_groups'] != null ? List<String>.from(row['joined_groups']) : [],
        'isVerified': row['is_verified'],
        'isBoosted': row['is_boosted'],
        'boostedUntil': row['boosted_until'],
        'createdAt': row['created_at'],
        'avatarPath': row['avatar_path'],
      }).where((profile) => profile['userId'] != currentUserId).toList();

      // Apply Advanced Matchmaking Algorithm
      for (final profile in list) {
        profile['matchScore'] = _calculateMatchScore(profile);
      }

      // Sort by Match Score descending
      list.sort((a, b) => (b['matchScore'] as int).compareTo(a['matchScore'] as int));

      // Cache loaded profiles for instant startup next time
      try {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('cached_profiles', json.encode(list));
      } catch (_) {}

      if (mounted) {
        setState(() {
          _profiles = list;
          _isFetching = false;
          _fetchCompleted = true;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing profiles: $e');
      if (mounted) {
        setState(() {
          _isFetching = false;
          _fetchCompleted = true;
        });
      }
    }
  }

  int _calculateMatchScore(Map<String, dynamic> otherProfile) {
    if (_currentUserProfile == null) {
      // Fallback deterministic match score based on user ID lengths
      return 60 + ((otherProfile['userId']?.toString().length ?? 0) % 35);
    }

    int score = 65; // Base compatibility

    // Age comparison (higher score if ages are close)
    final myAge = _currentUserProfile!['age'] as int? ?? 25;
    final otherAge = otherProfile['age'] as int? ?? 25;
    final ageDiff = (myAge - otherAge).abs();
    if (ageDiff <= 3) {
      score += 15;
    } else if (ageDiff <= 6) {
      score += 8;
    }

    // Location comparison
    final myCountry = _currentUserProfile!['country'] as String? ?? '';
    final otherCountry = otherProfile['country'] as String? ?? '';
    if (myCountry.isNotEmpty && otherCountry.isNotEmpty && myCountry.toLowerCase() == otherCountry.toLowerCase()) {
      score += 10;
      final myCity = _currentUserProfile!['city'] as String? ?? '';
      final otherCity = otherProfile['city'] as String? ?? '';
      if (myCity.isNotEmpty && otherCity.isNotEmpty && myCity.toLowerCase() == otherCity.toLowerCase()) {
        score += 5;
      }
    }

    // Match goals / lookingFor status comparison
    final myGoal = _currentUserProfile!['lookingFor'] as String? ?? '';
    final otherGoal = otherProfile['lookingFor'] as String? ?? '';
    if (myGoal.isNotEmpty && otherGoal.isNotEmpty && myGoal.toLowerCase() == otherGoal.toLowerCase()) {
      score += 5;
    }

    // Limit maximum to 99% (leaving 100% for the absolute perfect connection)
    return score > 99 ? 99 : score;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(LucideIcons.heart, color: colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            Text(
              'Dating Connect',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: colorScheme.onSurface),
            ),
          ],
        ),
        backgroundColor: colorScheme.surfaceContainer,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.sparkles, color: Colors.amberAccent),
            tooltip: 'Subscription Plan',
            onPressed: () {
              Navigator.pushNamed(context, '/paywall');
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Column(
          children: [
            if (_adLoaded && _bannerAd != null && SubscriptionService.shouldShowGeneralAds)
              Container(
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            Expanded(
              child: (_isFetching || !_fetchCompleted) && _profiles.isEmpty
                  ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                  : RefreshIndicator(
                      onRefresh: _refreshProfiles,
                      child: _profiles.isEmpty
                          ? Center(
                              child: Text(
                                'No profiles found nearby. Pull to refresh!',
                                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                              ),
                            )
                          : _wrapResponsive(
                              GridView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 0.72,
                                ),
                                itemCount: _profiles.length,
                                itemBuilder: (context, index) {
                                  final profile = _profiles[index];
                                  return _buildProfileGridTile(profile);
                                },
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileGridTile(Map<String, dynamic> profile) {
    final name = profile['fullName'] ?? 'User';
    final age = profile['age'] ?? 18;
    final city = profile['city'] ?? '';
    final country = profile['country'] ?? '';
    final matchScore = profile['matchScore'] as int? ?? 65;
    final isVerified = profile['isVerified'] == true;
    final isBoosted = profile['isBoosted'] == true;
    final photos = profile['photos'] as List<dynamic>? ?? [];

    Widget imageWidget;
    if (photos.isNotEmpty && photos[0].toString().isNotEmpty) {
      final fileUrl = StorageService.buildFileUrl(photos[0].toString());
      imageWidget = CachedNetworkImage(
        imageUrl: fileUrl,
        fit: BoxFit.cover,
        // Swipe cards are full-width — cap at 800px to avoid loading
        // full-resolution images into memory.
        memCacheWidth: 800,
        placeholder: (context, url) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildFallbackAvatar(name),
      );
    } else {
      imageWidget = _buildFallbackAvatar(name);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: profile['userId']),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isBoosted ? Colors.amberAccent.withOpacity(0.5) : Colors.white.withOpacity(0.08),
            width: isBoosted ? 2.0 : 1.0,
          ),
          boxShadow: isBoosted
              ? [
                  BoxShadow(
                    color: Colors.amberAccent.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Profile photo or fallback
            Positioned.fill(child: imageWidget),
            // Bottom Gradient Overlay for readability
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black38,
                      Colors.black87,
                    ],
                  ),
                ),
              ),
            ),
            // Match score badge
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.pinkAccent.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.heart, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '$matchScore% Match',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isBoosted)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.zap, color: Colors.black, size: 12),
                ),
              ),
            // User details at the bottom
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$name, $age',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: Icon(LucideIcons.checkCircle, color: Colors.blueAccent, size: 14),
                        ),
                    ],
                  ),
                  if (city.isNotEmpty || country.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(LucideIcons.mapPin, color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            city.isNotEmpty ? '$city, $country' : country,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String name) {
    final colorScheme = Theme.of(context).colorScheme;
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _wrapResponsive(Widget child) {
    return ResponsivePage(
      maxWidth: 960,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      child: child,
    );
  }

  Widget _buildBottomNav() {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<String?>(
      future: SessionStore.ensureUserId(),
      builder: (context, snapshot) {
        final hasSession = snapshot.data != null;

        return BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: colorScheme.surfaceContainer,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          currentIndex: 0,
          onTap: (index) {
            switch (index) {
              case 0:
                break;
              case 1:
                Navigator.pushReplacementNamed(context, '/groups');
                break;
              case 2:
                if (hasSession) {
                  Navigator.pushReplacementNamed(context, '/chat');
                } else {
                  Navigator.pushNamed(context, '/login');
                }
                break;
              case 3:
                if (hasSession) {
                  Navigator.pushReplacementNamed(context, '/profile');
                } else {
                  Navigator.pushNamed(context, '/login');
                }
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.users),
              label: 'Groups',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.messageCircle),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.user),
              label: 'Profile',
            ),
          ],
        );
      },
    );
  }
}
