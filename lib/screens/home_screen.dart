import 'dart:math';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../components/create_post.dart';
import '../components/post_card.dart';
import '../components/responsive_page.dart';
import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';
import 'live_stream_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showPostIcon = false;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _allPosts = [];
  bool _isLoading = true;
  final int _displayCount = 2;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final res = await AppwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.postsCollectionId,
        queries: [
          Query.orderDesc('createdAt'),
        ],
      );

      final postsList = res.documents
          .map((doc) => {
                ...doc.data,
                'id': doc.$id,
              })
          .toList();

      final authorIds = postsList
          .map((p) => p['authorId'] as String?)
          .where((id) => id != null)
          .toSet()
          .toList();

      final authorsById = <String, Map<String, dynamic>>{};
      if (authorIds.isNotEmpty) {
        final authorRes = await AppwriteService.databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.profilesCollectionId,
          queries: [
            Query.equal('userId', authorIds),
          ],
        );

        for (final doc in authorRes.documents) {
          final authorMap = {
            ...doc.data,
            'id': doc.$id,
          };
          authorMap['isBoostedActive'] = _isBoostActive(authorMap);
          authorsById[authorMap['userId'] as String] = authorMap;
        }
      }

      for (final post in postsList) {
        final authorId = post['authorId'] as String?;
        if (authorId != null && authorsById.containsKey(authorId)) {
          post['author'] = authorsById[authorId];
        }
      }

      final boosted = postsList
          .where((p) => p['author']?['isBoostedActive'] == true)
          .toList();
      final regular = postsList
          .where((p) => p['author']?['isBoostedActive'] != true)
          .toList();

      final userId = await SessionStore.ensureUserId() ?? '';
      final seed = userId.hashCode;
      regular.shuffle(Random(seed));

      final combined = [...boosted, ...regular];

      setState(() {
        _allPosts = combined;
        _posts = List.from(_allPosts.take(_displayCount));
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _loadMorePosts() {
    if (_allPosts.isEmpty) return;
    if (_posts.length >= _allPosts.length) return;
    setState(() {
      final nextBatch = _allPosts.skip(_posts.length).take(10);
      _posts.addAll(nextBatch);
    });
  }

  void _onPostCreated(Map<String, dynamic> newPost) {
    setState(() {
      _allPosts.insert(0, newPost);
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
    final showLive = !kIsWeb;
    if (!showLive) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Global Dating Chat'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
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
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _wrapResponsive(
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                elevation: 0,
                child: ListTile(
                  leading: Icon(
                    LucideIcons.rocket,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text(
                    'Fast Matchmaking from Admin',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Get personal help from an admin to find better matches, faster.',
                  ),
                  trailing: const Icon(LucideIcons.arrowRight),
                  onTap: () => Navigator.pushNamed(context, '/fast-match'),
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
                          final post = _posts[index];
                          return PostCard(post: post);
                        },
                        childCount: _posts.length,
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
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey,
      currentIndex: 0,
      onTap: (index) {
        switch (index) {
          case 0:
            // Already on home
            break;
          case 1:
            Navigator.pushNamed(context, '/groups');
            break;
          case 2:
            Navigator.pushNamed(context, '/chat');
            break;
          case 3:
            Navigator.pushNamed(context, '/profile');
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
