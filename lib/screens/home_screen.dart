import 'dart:math';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/create_post.dart';
import '../components/post_card.dart';
import '../components/responsive_page.dart';
import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';
import '../services/admob_service.dart';
import '../services/push_registration_service.dart';
import '../services/cache_service.dart';
import '../services/permission_service.dart';
import 'live_stream_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  bool _showPostIcon = false;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  final int _initialCount = 6;
  final Map<int, BannerAd> _bannerAds = {};
  final Map<int, NativeAd> _nativeAds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _loadInitialPosts();
    _requestPermissions();
    _scrollController.addListener(() {
      final shouldShow = _scrollController.offset > 50;
      if (shouldShow != _showPostIcon) {
        setState(() {
          _showPostIcon = shouldShow;
        });
      }
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMorePosts();
      }
    });
  }

  Future<void> _requestPermissions() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      await PermissionService.requestAllPermissions(context);
    }
  }

  Future<void> _loadCachedData() async {
    final cachedPosts = await CacheService.getCachedPosts();
    if (cachedPosts.isNotEmpty) {
      setState(() {
        _posts = cachedPosts;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final ad in _bannerAds.values) {
      ad.dispose();
    }
    for (final ad in _nativeAds.values) {
      ad.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialPosts() async {
    setState(() => _isLoading = false);
    
    try {
      final res = await AppwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.postsCollectionId,
        queries: [Query.orderDesc('createdAt'), Query.limit(_initialCount)],
      );

      final postsList = res.documents.map((doc) => {...doc.data, 'id': doc.$id}).toList();
      
      if (mounted) {
        setState(() {
          _posts = postsList;
        });
      }

      CacheService.cachePosts(postsList);
      _loadAuthorsInBackground();
      _migrateExistingUserNotifications();
    } catch (_) {}
  }

  Future<void> _loadAuthorsInBackground() async {
    final authorIds = _posts.map((p) => p['authorId'] as String?).where((id) => id != null).toSet().toList();
    if (authorIds.isEmpty) return;

    try {
      final authorRes = await AppwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        queries: [Query.equal('userId', authorIds)],
      );

      final authorsById = <String, Map<String, dynamic>>{};
      for (final doc in authorRes.documents) {
        final authorMap = {...doc.data, 'id': doc.$id};
        authorMap['isBoostedActive'] = _isBoostActive(authorMap);
        authorsById[authorMap['userId'] as String] = authorMap;
      }

      setState(() {
        for (final post in _posts) {
          final authorId = post['authorId'] as String?;
          if (authorId != null && authorsById.containsKey(authorId)) {
            post['author'] = authorsById[authorId];
          }
        }
      });
    } catch (_) {}
  }



  void _loadMorePosts() {
    if (_posts.length >= 100) return;
    
    AppwriteService.databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.postsCollectionId,
      queries: [Query.orderDesc('createdAt'), Query.limit(6), Query.offset(_posts.length)],
    ).then((res) {
      if (!mounted) return;
      final newPosts = res.documents.map((doc) => {...doc.data, 'id': doc.$id}).toList();
      setState(() {
        _posts.addAll(newPosts);
      });
    });
  }

  /// One-time migration for existing users to subscribe to notifications
  Future<void> _migrateExistingUserNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrated = prefs.getBool('notifications_migrated') ?? false;
      
      if (!migrated) {
        final userId = await SessionStore.ensureUserId();
        if (userId != null) {
          // Register existing user for push notifications
          await PushRegistrationService.forceRegister();
          
          // Mark as migrated
          await prefs.setBool('notifications_migrated', true);
        }
      }
    } catch (_) {
      // Silent fail - migration is best effort
    }
  }

  void _onPostCreated(Map<String, dynamic> newPost) {
    setState(() {
      _posts.insert(0, newPost);
    });
  }

  void _showCreatePostDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CreatePost(onPostCreated: (post) {
            _onPostCreated(post);
            Navigator.pop(context);
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final showLive = !kIsWeb;
    if (!showLive) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Global Dating Chat'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.badgeDollarSign, color: Colors.green),
              tooltip: 'Coins',
              onPressed: () => Navigator.pushNamed(context, '/coins'),
            ),
            IconButton(
              icon: const Icon(LucideIcons.edit),
              onPressed: _showPostIcon
                  ? _showCreatePostDialog
                  : () {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
        body: _isLoading ? _wrapResponsive(_buildLoadingState()) : _buildFeed(),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Global Dating Chat'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.badgeDollarSign, color: Colors.green),
              tooltip: 'Coins',
              onPressed: () => Navigator.pushNamed(context, '/coins'),
            ),
            IconButton(
              icon: const Icon(LucideIcons.edit),
              onPressed: _showPostIcon
                  ? _showCreatePostDialog
                  : () {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Feed', icon: Icon(LucideIcons.list)),
              Tab(text: 'Live', icon: Icon(LucideIcons.radio)),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
        body: const TabBarView(
          children: [
            _FeedTabWrapper(),
            LiveStreamTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    final colorScheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        await _loadInitialPosts();
      },
      child: _wrapResponsive(
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary.withOpacity(0.1), colorScheme.secondary.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: InkWell(
                  onTap: () => Navigator.pushNamed(context, '/fast-match'),
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.rocket,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fast Matchmaking from Admin',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Get personal help from an admin to find better matches, faster.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.arrowRight,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!_showPostIcon)
              SliverToBoxAdapter(
                child: CreatePost(onPostCreated: _onPostCreated),
              ),
            _posts.isEmpty
                ? const SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No posts yet. Be the first to share!',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final postIndex = index ~/ 2;
                          final isAd = index.isOdd;
                          
                          if (isAd && !kIsWeb) {
                            final adIndex = index ~/ 2;
                            if (adIndex % 3 == 1) {
                              return _buildBannerAd(adIndex);
                            } else if (adIndex % 3 == 2) {
                              return _buildNativeAd(adIndex);
                            }
                            return const SizedBox.shrink();
                          }
                          
                          if (postIndex >= _posts.length) return null;
                          final post = _posts[postIndex];
                          return PostCard(post: post);
                        },
                        childCount: _posts.length * 2,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _wrapResponsive(Widget child) {
    return ResponsivePage(
      maxWidth: 960,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: child,
    );
  }

  bool _isBoostActive(Map<String, dynamic> author) {
    if (author['isBoosted'] != true) return false;
    final until = author['boostedUntil'];
    if (until == null) return true;
    try {
      return DateTime.parse(until.toString()).isAfter(DateTime.now());
    } catch (_) {
      return true;
    }
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.all(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 200),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 120,
                        constraints: const BoxConstraints(minHeight: 16),
                        color: Colors.grey[300],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 80),
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(width: 60, constraints: const BoxConstraints(minHeight: 20), color: Colors.grey[300]),
                      const SizedBox(width: 16),
                      Container(width: 60, constraints: const BoxConstraints(minHeight: 20), color: Colors.grey[300]),
                      const SizedBox(width: 16),
                      Container(width: 60, constraints: const BoxConstraints(minHeight: 20), color: Colors.grey[300]),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return FutureBuilder<String?>(
      future: SessionStore.ensureUserId(),
      builder: (context, snapshot) {
        final hasSession = snapshot.data != null;
        
        return BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          currentIndex: 0,
          onTap: (index) {
            switch (index) {
              case 0:
                break;
              case 1:
                Navigator.pushNamed(context, '/groups');
                break;
              case 2:
                if (hasSession) {
                  Navigator.pushNamed(context, '/chat');
                } else {
                  Navigator.pushNamed(context, '/login');
                }
                break;
              case 3:
                if (hasSession) {
                  Navigator.pushNamed(context, '/profile');
                } else {
                  Navigator.pushNamed(context, '/login');
                }
                break;
            }
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.users),
              label: 'Groups',
            ),
            BottomNavigationBarItem(
              icon: const Icon(LucideIcons.messageCircle),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: const Icon(LucideIcons.user),
              label: 'Profile',
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildBannerAd(int index) {
    if (!_bannerAds.containsKey(index)) {
      final ad = AdMobService.createBannerAd();
      ad.load();
      _bannerAds[index] = ad;
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 50,
      child: AdWidget(ad: _bannerAds[index]!),
    );
  }
  
  Widget _buildNativeAd(int index) {
    if (!_nativeAds.containsKey(index)) {
      AdMobService.createNativeAd().then((ad) {
        if (ad != null && mounted) {
          setState(() {
            _nativeAds[index] = ad;
          });
        }
      });
    }
    
    if (!_nativeAds.containsKey(index)) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 120,
      child: AdWidget(ad: _nativeAds[index]!),
    );
  }
}

class _FeedTabWrapper extends StatelessWidget {
  const _FeedTabWrapper();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_HomeScreenState>();
    if (state == null) {
      return const SizedBox.shrink();
    }
    return state._isLoading
        ? state._wrapResponsive(state._buildLoadingState())
        : state._buildFeed();
  }
}
