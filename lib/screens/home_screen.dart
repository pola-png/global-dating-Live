import 'dart:async';
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

import 'live_stream_screen.dart';
import '../services/update_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  bool _showPostIcon = false;
  List<Map<String, dynamic>> _posts = [];
  bool _isFetching = false;
  bool _fetchCompleted = false;
  DateTime? _fetchStartTime;
  final int _initialCount = 6;
  final Map<int, BannerAd> _bannerAds = {};
  final Map<int, NativeAd> _nativeAds = {};
  RealtimeSubscription? _postsSubscription;

  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFeed());
    UpdateService.checkForUpdates(context);
    _setupRealtimeSubscription();
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

  Future<void> _initFeed() async {
    try {
      await _loadCachedData();
    } catch (_) {
      // ignore cache errors
    }
    _refreshFeed();
  }

  Future<void> _loadCachedData() async {
    final cachedPosts = await CacheService.getCachedPosts();
    if (cachedPosts.isNotEmpty) {
      setState(() {
        _posts = cachedPosts;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _postsSubscription?.close();
    for (final ad in _bannerAds.values) {
      ad.dispose();
    }
    for (final ad in _nativeAds.values) {
      ad.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshFeed() async {
    try {
      if (mounted) {
        setState(() {
          _isFetching = true;
          _fetchCompleted = false;
        });
      }

      final postsRes = await AppwriteService.databases
          .listDocuments(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.postsCollectionId,
            queries: [Query.orderDesc('createdAt'), Query.limit(_initialCount)],
          )
          .timeout(const Duration(seconds: 10));

      final postsList = postsRes.documents.map((doc) => {...doc.data, 'id': doc.$id}).toList();

      if (postsList.isEmpty) {
        if (mounted) {
          setState(() {
            _posts = [];
            _isFetching = false;
            _fetchCompleted = true;
          });
        }
        return;
      }

      final authorIds = postsList
          .map((p) => p['authorId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      final authorsById = <String, Map<String, dynamic>>{};
      if (authorIds.isNotEmpty) {
        try {
          final authorRes = await AppwriteService.databases
              .listDocuments(
                databaseId: AppwriteConfig.databaseId,
                collectionId: AppwriteConfig.profilesCollectionId,
                queries: [Query.equal('userId', authorIds)],
              )
              .timeout(const Duration(seconds: 8));

          for (final doc in authorRes.documents) {
            final authorMap = {...doc.data, 'id': doc.$id};
            authorMap['isBoostedActive'] = _isBoostActive(authorMap);
            authorsById[authorMap['userId'] as String] = authorMap;
          }
        } catch (e) {
          debugPrint('Failed to fetch authors: $e');
        }
      }

      for (final post in postsList) {
        final authorId = post['authorId'] as String?;
        if (authorId != null && authorsById.containsKey(authorId)) {
          post['author'] = authorsById[authorId];
        }
      }

      if (mounted) {
        setState(() {
          _posts = List.from(postsList);
          _isFetching = false;
          _fetchCompleted = true;
        });
      }

      if (postsList.isNotEmpty) CacheService.cachePosts(postsList);
      _migrateExistingUserNotifications();
    } catch (e) {
      debugPrint('Error refreshing feed: $e');
      if (mounted) {
        setState(() {
          _isFetching = false;
          _fetchCompleted = true;
        });
      }
    }
  }

  void _loadMorePosts() {
    if (_posts.length >= 100) return;

    AppwriteService.databases.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.postsCollectionId,
      queries: [Query.orderDesc('createdAt'), Query.limit(6), Query.offset(_posts.length)],
    ).then((res) async {
      if (!mounted) return;
      final newPosts = res.documents.map((doc) => {...doc.data, 'id': doc.$id}).toList();

      final existingIds = _posts.map((p) => p['id']).toSet();
      final uniqueNewPosts = newPosts.where((p) => !existingIds.contains(p['id'])).toList();

      if (uniqueNewPosts.isEmpty) return;

      final authorIds = uniqueNewPosts
          .map((p) => p['authorId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> authorsById = {};
      if (authorIds.isNotEmpty) {
        try {
          final authorRes = await AppwriteService.databases.listDocuments(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.profilesCollectionId,
            queries: [Query.equal('userId', authorIds)],
          );

          for (final doc in authorRes.documents) {
            final authorMap = {...doc.data, 'id': doc.$id};
            authorMap['isBoostedActive'] = _isBoostActive(authorMap);
            authorsById[authorMap['userId'] as String] = authorMap;
          }
        } catch (e) {
          debugPrint('Failed to fetch authors for more posts: $e');
        }
      }

      for (final post in uniqueNewPosts) {
        final authorId = post['authorId'] as String?;
        if (authorId != null && authorsById.containsKey(authorId)) {
          post['author'] = authorsById[authorId];
        }
      }

      if (mounted) {
        setState(() {
          _posts.addAll(uniqueNewPosts);
        });
      }
    }).catchError((error) {
      debugPrint('Error loading more posts: $error');
    });
  }

  void _setupRealtimeSubscription() {
    try {
      _postsSubscription = AppwriteService.realtime.subscribe([
        'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.postsCollectionId}.documents'
      ]);
      
      _postsSubscription!.stream.listen((response) {
        if (!mounted) return;
        
        final eventType = response.events.first;
        final payload = response.payload;
        
        if (eventType.contains('create')) {
          _handleNewPost(payload);
        } else if (eventType.contains('update')) {
          _handlePostUpdate(payload);
        }
      });
    } catch (e) {
      debugPrint('Failed to setup realtime subscription: $e');
    }
  }
  
  void _handleNewPost(Map<String, dynamic> postData) async {
    try {
      final authorId = postData['authorId'] as String?;
      if (authorId != null) {
        final authorDoc = await AppwriteService.databases.getDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.profilesCollectionId,
          documentId: authorId,
        );
        postData['author'] = <String, dynamic>{...authorDoc.data, 'id': authorDoc.$id};
      }
      
      setState(() {
        _posts.insert(0, <String, dynamic>{...postData, 'id': postData['\$id']});
      });
    } catch (e) {
      debugPrint('Error handling new post: $e');
    }
  }
  
  void _handlePostUpdate(Map<String, dynamic> postData) {
    setState(() {
      final index = _posts.indexWhere((p) => p['id'] == postData['\$id']);
      if (index != -1) {
        _posts[index] = <String, dynamic>{..._posts[index], ...postData};
      }
    });
  }

  Future<void> _migrateExistingUserNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrated = prefs.getBool('notifications_migrated') ?? false;
      
      if (!migrated) {
        final userId = await SessionStore.ensureUserId();
        if (userId != null) {
          await PushRegistrationService.forceRegister();
          await prefs.setBool('notifications_migrated', true);
        }
      }
    } catch (_) {
    }
  }

  void _onPostCreated(Map<String, dynamic> newPost) {
    setState(() {
      final existingIndex = _posts.indexWhere((p) => p['id'] == newPost['id']);
      if (existingIndex == -1) {
        _posts.insert(0, newPost);
      }
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
    
    return DefaultTabController(
      length: showLive ? 2 : 1,
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
              onPressed: () async {
                final userId = await SessionStore.ensureUserId();
                if (!mounted) return;
                if (userId == null) {
                  Navigator.pushNamed(context, '/login');
                } else {
                  Navigator.pushNamed(context, '/coins');
                }
              },
            ),
            IconButton(
              icon: const Icon(LucideIcons.download),
              tooltip: 'Check Updates',
              onPressed: () => UpdateService.checkForUpdates(context, showNoUpdateDialog: true),
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
          bottom: showLive ? const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Feed', icon: Icon(LucideIcons.list)),
              Tab(text: 'Live', icon: Icon(LucideIcons.radio)),
            ],
          ) : null,
        ),
        bottomNavigationBar: _buildBottomNav(),
        body: showLive
            ? TabBarView(
                children: [
                  _shouldShowLoading() ? _wrapResponsive(_buildLoadingState()) : _buildFeed(),
                  _buildLiveTab(),
                ],
              )
            : (_shouldShowLoading() ? _wrapResponsive(_buildLoadingState()) : _buildFeed()),
      ),
    );
  }

  Widget _buildFeed() {
    final colorScheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        await _refreshFeed();
      },
      child: _wrapResponsive(
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary.withValues(alpha: 0.1), colorScheme.secondary.withValues(alpha: 0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: InkWell(
                  onTap: () async {
                    final userId = await SessionStore.ensureUserId();
                    if (!mounted) return;
                    if (userId == null) {
                      Navigator.pushNamed(context, '/login');
                    } else {
                      Navigator.pushNamed(context, '/fast-match');
                    }
                  },
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
                              color: colorScheme.primary.withValues(alpha: 0.3),
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
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
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
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (kIsWeb) {
                          if (index >= _posts.length) return null;
                          return PostCard(post: _posts[index]);
                        }
                        
                        final postIndex = index ~/ 3;
                        final isAd = index % 3 == 2;
                        
                        if (isAd) {
                          final adIndex = postIndex;
                          return _buildBannerAd(adIndex);
                        }
                        
                        final actualPostIndex = index - (index ~/ 3);
                        if (actualPostIndex >= _posts.length) return null;
                        return PostCard(post: _posts[actualPostIndex]);
                      },
                      childCount: kIsWeb ? _posts.length : _posts.length + (_posts.length ~/ 2),
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
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      child: child,
    );
  }

  bool _shouldShowLoading() {
    if (_posts.isNotEmpty) return false;
    if (_isFetching && !_fetchCompleted) return true;
    if (_fetchStartTime != null) {
      final elapsed = DateTime.now().difference(_fetchStartTime!).inSeconds;
      if (elapsed > 15 && _posts.isEmpty) return true;
    }
    return false;
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
                      height: 16,
                      color: Colors.grey[300],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(width: 60, height: 20, color: Colors.grey[300]),
                    const SizedBox(width: 16),
                    Container(width: 60, height: 20, color: Colors.grey[300]),
                    const SizedBox(width: 16),
                    Container(width: 60, height: 20, color: Colors.grey[300]),
                  ],
                ),
              ],
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
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.messageCircle),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.user),
              label: 'Profile',
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildLiveTab() {
    return FutureBuilder<String?>(
      future: SessionStore.ensureUserId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final hasSession = snapshot.data != null;
        
        if (!hasSession) {
          return _wrapResponsive(
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.lock,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Authentication Required',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please log in to access live streaming features',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: const Text('Log In'),
                  ),
                ],
              ),
            ),
          );
        }
        
        return const LiveStreamTab();
      },
    );
  }

  Widget _buildBannerAd(int index) {
    if (!_bannerAds.containsKey(index)) {
      final ad = AdMobService.createBannerAd();
      ad.load();
      _bannerAds[index] = ad;
    }
    
    return SizedBox(
      height: 60,
      child: AdWidget(ad: _bannerAds[index]!),
    );
  }
}

