import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
  bool _isMenuOpen = false;

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
    _loadCachedProfiles();

    final userId = await SessionStore.ensureUserId();
    if (!mounted) return;
    if (userId == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Parallel background fetch for 2x faster data loading
    Future.wait([
      _fetchCurrentUserProfile(),
      _refreshProfiles(),
    ]);
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

    return PopScope(
      canPop: !_isMenuOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isMenuOpen) {
          setState(() {
            _isMenuOpen = false;
          });
        }
      },
      child: Scaffold(
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
              icon: AnimatedRotation(
                turns: _isMenuOpen ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isMenuOpen ? LucideIcons.x : LucideIcons.ellipsisVertical,
                  color: _isMenuOpen ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
              tooltip: _isMenuOpen ? 'Close Menu' : 'Menu & Options',
              onPressed: () {
                setState(() {
                  _isMenuOpen = !_isMenuOpen;
                });
              },
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
        body: Stack(
          children: [
            // Main Content Area
            Column(
              children: [
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
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                if (_adLoaded && _bannerAd != null && SubscriptionService.shouldShowGeneralAds)
                  Container(
                    alignment: Alignment.center,
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
            // Semi-transparent backdrop barrier
            if (_isMenuOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isMenuOpen = false;
                    });
                  },
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ),
            // Slide-in Full Height Side Panel (Touches bottom nav, sits below top bar)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              right: _isMenuOpen ? 0 : -((MediaQuery.of(context).size.width * 0.88).clamp(320.0, 380.0) + 30),
              width: (MediaQuery.of(context).size.width * 0.88).clamp(320.0, 380.0),
              child: _buildRightSideMenu(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightSideMenu(ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surfaceContainerHigh,
      elevation: 12,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // VIP Upgrade Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE5A623), Color(0xFFD47C10), Color(0xFF9E4800)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE5A623).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.crown, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'VIP Membership',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Unlimited Swipes, Verified Badge & Ad-Free Experience',
                    style: TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _isMenuOpen = false);
                        Navigator.pushNamed(context, '/paywall');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF9E4800),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Upgrade Now',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Buy Coins Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.coins, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dating Coins',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Send gifts & direct chats',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _isMenuOpen = false);
                      Navigator.pushNamed(context, '/coins');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    child: const Text(
                      'Get Coins',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'SAFETY & POLICIES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),

            // Child Safety Standards
            _buildSideMenuItem(
              icon: LucideIcons.shieldAlert,
              iconColor: Colors.redAccent,
              title: 'Child Safety Standards',
              subtitle: '18+ Adult-Only & CSAE Policy',
              onTap: () {
                setState(() => _isMenuOpen = false);
                Navigator.pushNamed(context, '/policy');
              },
            ),

            // Privacy Policy
            _buildSideMenuItem(
              icon: LucideIcons.lock,
              iconColor: Colors.blueAccent,
              title: 'Privacy Policy',
              subtitle: 'Data usage & deletion rights',
              onTap: () {
                setState(() => _isMenuOpen = false);
                Navigator.pushNamed(context, '/policy');
              },
            ),

            // Community Guidelines & Rules
            _buildSideMenuItem(
              icon: LucideIcons.fileText,
              iconColor: Colors.purpleAccent,
              title: 'Community Rules',
              subtitle: 'Guidelines & standards',
              onTap: () {
                setState(() => _isMenuOpen = false);
                Navigator.pushNamed(context, '/policy');
              },
            ),

            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'SUPPORT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),

            // Help & Support
            _buildSideMenuItem(
              icon: LucideIcons.lifeBuoy,
              iconColor: Colors.tealAccent,
              title: 'Admin Support',
              subtitle: 'Reach support team',
              onTap: () {
                setState(() => _isMenuOpen = false);
                Navigator.pushNamed(context, '/admin/support');
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSideMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
        memCacheWidth: 400,
        fadeInDuration: const Duration(milliseconds: 100),
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
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
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
