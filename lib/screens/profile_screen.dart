import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/avatar_widget.dart';
import '../components/report_dialog.dart';
import '../services/supabase_service.dart';
import '../services/account_deletion_service.dart';
import '../services/storage_service.dart';
import '../services/wallet_service.dart';
import '../services/admob_service.dart';
import '../services/subscription_service.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isOwnProfile = false;
  int _coinBalance = 0;
  String? _fastMatchChatRoom;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkFastMatchStatus();
  }

  Future<void> _checkFastMatchStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final chatRoomId = prefs.getString('fast_match_chat_room');
    if (mounted) {
      setState(() => _fastMatchChatRoom = chatRoomId);
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = await SessionStore.ensureUserId();
      if (currentUserId == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      final targetUserId =
          widget.userId == null ? currentUserId : widget.userId!;
      _isOwnProfile = targetUserId == currentUserId;

      final doc = await SupabaseService.client
          .from('users')
          .select('*')
          .eq('id', targetUserId)
          .maybeSingle();

      if (doc == null) {
        final user = SupabaseService.client.auth.currentUser;
        if (user != null) {
          final email = user.email ?? '';
          final fullName = 'New User';
          await SupabaseService.client.from('users').insert({
            'id': targetUserId,
            'email': email,
            'full_name': fullName,
            'age': 18,
            'country': '',
            'city': '',
            'looking_for': '',
            'relationship_status': '',
            'about': '',
            'avatar_letter': 'U',
            'photos': <String>[],
            'joined_groups': <String>[],
            'is_verified': false,
            'created_at': DateTime.now().toIso8601String(),
          });
          await _loadProfile();
          return;
        }
      }

      final profileResponse = {
        'id': doc!['id'],
        'userId': doc['id'],
        'fullName': doc['full_name'],
        'email': doc['email'],
        'age': doc['age'],
        'country': doc['country'],
        'city': doc['city'],
        'lookingFor': doc['looking_for'],
        'relationshipStatus': doc['relationship_status'],
        'about': doc['about'],
        'avatarLetter': doc['avatar_letter'],
        'photos': doc['photos'] != null ? List<String>.from(doc['photos']) : [],
        'joinedGroups': doc['joined_groups'] != null ? List<String>.from(doc['joined_groups']) : [],
        'isVerified': doc['is_verified'],
        'isBoosted': doc['is_boosted'],
        'boostedUntil': doc['boosted_until'],
        'createdAt': doc['created_at'],
        'avatarPath': doc['avatar_path'],
      };

      if (mounted) {
        setState(() {
          _profile = profileResponse;
          _isLoading = false;
          _coinBalance = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startChat() async {
    if (_profile == null) return;

    final otherUserId = _profile!['id'] as String;
    final isPaid = SubscriptionService.currentPlan != SubscriptionPlan.none;

    final canChat = await SubscriptionService.canChatWithUser(otherUserId);
    if (!canChat) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Connection Limit Reached'),
            content: const Text(
              'The Basic plan allows chatting with up to 5 connections.\n\n'
              'You can upgrade to the Standard plan to chat with unlimited partners, '
              'or spend 10 coins to unlock this specific connection.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final balance = await WalletService.getBalance();
                  if (balance >= SubscriptionService.coinCostPerConnection) {
                    final spent = await WalletService.spendCoins(SubscriptionService.coinCostPerConnection);
                    if (spent) {
                      await SubscriptionService.unlockConnectionWithCoins(otherUserId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Successfully unlocked connection with 10 coins!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        // Trigger start chat again since it's now unlocked
                        _startChat();
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to process coin deduction.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } else {
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx2) => AlertDialog(
                          title: const Text('Insufficient Coins'),
                          content: Text(
                            'You need 10 coins to unlock this connection, but only have $balance coins.\n\n'
                            'Earn coins by watching ads or buy coin packs.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx2),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx2);
                                Navigator.pushNamed(context, '/coin_purchase');
                              },
                              child: const Text('Get Coins'),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                },
                child: const Text('Spend 10 Coins'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/paywall');
                },
                child: const Text('Upgrade'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Show toast for ads requirement on mobile only for unpaid users
    if (!kIsWeb && !isPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to watch ads to start a chat'),
          duration: Duration(seconds: 2),
        ),
      );
      
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Loading ads...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }

    try {
      final currentUserId = await SessionStore.ensureUserId();
      if (currentUserId == null) return;

      final existingRooms = await SupabaseService.client
          .from('chat_rooms')
          .select('*')
          .or('and(user1_id.eq.$currentUserId,user2_id.eq.$otherUserId),and(user1_id.eq.$otherUserId,user2_id.eq.$currentUserId)');

      Map<String, dynamic>? chatRoomDoc;
      if (existingRooms.isNotEmpty) {
        chatRoomDoc = existingRooms.first;
      } else {
        chatRoomDoc = await SupabaseService.client.from('chat_rooms').insert({
          'user1_id': currentUserId,
          'user2_id': otherUserId,
          'last_active': DateTime.now().toIso8601String(),
        }).select().single();
      }

      final chatRoomId = chatRoomDoc['id'].toString();

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/chat/$chatRoomId',
          arguments: {
            'chatRoom': {'id': chatRoomId},
            'otherUser': _profile,
          },
        );
      }

      // Show ad after chat is opened (only on mobile for unpaid users)
      if (!kIsWeb && !isPaid) {
        final ad = await AdMobService.loadRewardedAd();
        if (ad != null) {
          await AdMobService.showRewardedAd(ad);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start chat')),
        );
      }
    }
  }

  Future<void> _refreshCoins() async {
    final coins = await WalletService.getBalance();
    if (mounted) setState(() => _coinBalance = coins);
  }

  Future<void> _boostProfile() async {
    const cost = 50;
    setState(() => _isLoading = true);
    final success = await WalletService.spendCoins(cost);
    if (!mounted) return;

    if (!success) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough coins to boost (50 coins needed). Redirecting to Buy Coins...'),
        ),
      );
      Navigator.pushNamed(context, '/coins');
      return;
    }

    try {
      final userId = await SessionStore.ensureUserId();
      if (userId != null) {
        await SupabaseService.client
            .from('users')
            .update({
              'is_boosted': true,
              'is_verified': true,
              'boosted_until': DateTime.now()
                  .add(const Duration(days: 14))
                  .toIso8601String(),
            })
            .eq('id', userId);
      }
      await _loadProfile();
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile boosted and verified!')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark boost on server, but coins deducted locally.')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _isLoading
          ? _buildLoadingState()
          : _profile == null
              ? _buildNotFoundState()
              : _buildModernProfileContent(),
      bottomNavigationBar: _isOwnProfile ? BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surfaceContainer,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        currentIndex: 3,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/groups');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/chat');
              break;
            case 3:
              // Already on profile
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
      ) : null,
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 16),
                Container(width: 200, height: 20, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Container(width: 150, height: 16, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Container(width: double.infinity, height: 40, color: Colors.grey[300]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(width: double.infinity, height: 100, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Container(width: double.infinity, height: 200, color: Colors.grey[300]),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return const Center(
      child: Text(
        'User profile not found',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildModernProfileContent() {
    final firstName = _profile!['fullName'].toString().split(' ')[0];
    final boostActive = _isBoostActive(_profile!);
    final isVerified = _profile!['isVerified'] == true;
    final isAdmin = _profile!['isAdmin'] == true;
    final colorScheme = Theme.of(context).colorScheme;
    
    return CustomScrollView(
      slivers: [
        // Modern app bar with gradient
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          floating: false,
          snap: false,
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          title: Text(
            _isOwnProfile ? 'My Profile' : firstName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
          actions: [
            if (!_isOwnProfile)
              IconButton(
                icon: const Icon(LucideIcons.flag, color: Colors.white),
                tooltip: 'Report User',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => ReportDialog(
                      reportedUserId: _profile!['id'].toString(),
                      context: 'profile',
                    ),
                  );
                },
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Avatar with modern styling
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: AvatarWidget(
                        avatarUrl: _profile!['avatarPath'] as String?,
                        photos: _profile!['photos'] != null ? List<String>.from(_profile!['photos']) : null,
                        avatarLetter: _profile!['avatarLetter'] ?? 'U',
                        radius: 50,
                        showVipBadge: false,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _profile!['fullName'] ?? 'Unknown User',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_profile!['isBoosted'] == true)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(Icons.verified, color: Colors.white, size: 20),
                      ),
                    if (isAdmin || isVerified || boostActive)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAdmin ? LucideIcons.shieldCheck : LucideIcons.checkCircle2,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isAdmin
                                    ? 'Admin'
                                    : boostActive && isVerified
                                        ? 'Verified & Boosted'
                                        : boostActive
                                            ? 'Boosted'
                                            : 'Verified',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Content sections
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Action buttons section
                _buildActionButtons(colorScheme, boostActive),
                
                const SizedBox(height: 32),
                
                // Support buttons (before Photo Gallery/About)
                if (_isOwnProfile) ...[
                  _buildSupportSection(isAdmin),
                  const SizedBox(height: 24),
                ],
                
                // Photo Gallery (Moved above About Me)
                if (_isOwnProfile || (_profile!['photos'] != null && (_profile!['photos'] as List).isNotEmpty)) ...[
                  _buildPhotoGallery(),
                  const SizedBox(height: 24),
                ],
                
                // About Me card
                _buildAboutCard(),
                
                const SizedBox(height: 24),
                
                // Details card
                _buildDetailsCard(),
                
                if (_isOwnProfile) ...[
                  const SizedBox(height: 24),
                  _buildProfileActions(),
                ],
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme, bool boostActive) {
    if (_isOwnProfile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/profile/edit'),
                  icon: const Icon(LucideIcons.edit, size: 18),
                  label: const Text('Edit Profile'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/coins'),
                  icon: const Icon(LucideIcons.badgeDollarSign, size: 18),
                  label: Text('$_coinBalance Coins'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!kIsWeb)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final ad = await AdMobService.loadRewardedAd();
                  if (ad == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ad not available, try again later')),
                      );
                    }
                    return;
                  }
                  
                  await AdMobService.showRewardedAd(ad);
                  // Always award coins after ad is shown
                  if (mounted) {
                    await WalletService.addCoins(30);
                    await _refreshCoins();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Successfully earned 30 coins!'), backgroundColor: Colors.green),
                    );
                  }
                },
                icon: const Icon(LucideIcons.tv, size: 18),
                label: const Text('Watch Ad for 30 Coins'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (!kIsWeb) const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: boostActive ? null : _boostProfile,
              icon: const Icon(LucideIcons.zap, size: 18),
              label: Text(
                boostActive ? 'Boosted (14 days)' : 'Boost Profile (50 coins)',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                disabledBackgroundColor: Colors.orange.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _startChat,
          icon: const Icon(LucideIcons.messageCircle, size: 18),
          label: const Text('Send Message'),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildSupportSection(bool isAdmin) {
    return Column(
      children: [
        if (_fastMatchChatRoom != null)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/chat/$_fastMatchChatRoom'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.withValues(alpha: 0.1), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.rocket, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fast Match Support',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chat with our team',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, color: Colors.orange.shade700),
                  ],
                ),
              ),
            ),
          ),
        if (_fastMatchChatRoom != null && isAdmin) const SizedBox(height: 16),
        if (isAdmin)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.red.withValues(alpha: 0.3),
              ),
            ),
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/admin/support'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.withValues(alpha: 0.1), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.headphones, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Dashboard',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage support requests',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, color: Colors.red.shade700),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAboutCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.user,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'About Me',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _profile!['about'] ?? 'No bio available',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.list,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGallery() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.image,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Photo Gallery',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isOwnProfile)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/profile/photos'),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Manage'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_profile!['photos'] is List && (_profile!['photos'] as List).isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: (_profile!['photos'] as List).length,
                itemBuilder: (context, index) {
                  final photoId = (_profile!['photos'] as List)[index] as String;
                  final photoUrl = StorageService.buildFileUrl(photoId);
                  return GestureDetector(
                    onTap: () => _showPhotoGallery(index),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          // Photo grid thumbnails — cap at 400px wide.
                          memCacheWidth: 400,
                          placeholder: (context, url) => Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              LucideIcons.image,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              LucideIcons.imageOff,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )
            else if (_isOwnProfile)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.imageOff,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No photos yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add some photos to make your profile more attractive!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/policy'),
                icon: const Icon(LucideIcons.fileText, size: 18),
                label: const Text('Privacy Policy'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  SessionStore.clear();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                icon: const Icon(LucideIcons.logOut, size: 18),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () {
            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Row(
                  children: [
                    Icon(LucideIcons.alertTriangle, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Account'),
                  ],
                ),
                content: const Text(
                  'Are you sure? This action cannot be undone. All your data will be permanently deleted.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => navigator.pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await AccountDeletionService.deleteCurrentUserData();
                        if (!mounted) return;
                        navigator.pushReplacementNamed('/login');
                      } catch (e) {
                        if (!mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Failed to delete account')),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 18),
          label: const Text(
            'Delete Account',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
  void _showPhotoGallery(int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: (_profile!['photos'] as List).length,
              itemBuilder: (context, index) {
                final photoId = (_profile!['photos'] as List)[index] as String;
                final photoUrl = StorageService.buildFileUrl(photoId);
                return InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.contain,
                    // Full-screen viewer — allow up to 1080px wide so quality
                    // is preserved while still avoiding huge bitmap allocations
                    // from very high-res originals.
                    memCacheWidth: 1080,
                  ),
                );
              },
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailGrid() {
    final details = [
      {'icon': LucideIcons.cake, 'label': 'Age', 'value': _profile!['age']?.toString() ?? 'N/A'},
      {'icon': LucideIcons.personStanding, 'label': 'Gender', 'value': _profile!['gender'] ?? 'N/A'},
      {'icon': LucideIcons.mapPin, 'label': 'Country', 'value': _profile!['country'] ?? 'N/A'},
      {'icon': LucideIcons.building2, 'label': 'City', 'value': _profile!['city'] ?? 'N/A'},
      {'icon': LucideIcons.heart, 'label': 'Looking For', 'value': _profile!['lookingFor'] ?? 'N/A'},
      {'icon': LucideIcons.glassWater, 'label': 'Status', 'value': _profile!['relationshipStatus'] ?? 'N/A'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: details.length,
      itemBuilder: (context, index) {
        final detail = details[index];
        return Row(
          children: [
            Icon(
              detail['icon'] as IconData,
              color: Theme.of(context).iconTheme.color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    detail['label'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    detail['value'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isBoostActive(Map<String, dynamic> profile) {
    if (profile['isBoosted'] != true) return false;
    final until = profile['boostedUntil'];
    if (until == null) return true;
    try {
      return DateTime.parse(until.toString()).isAfter(DateTime.now());
    } catch (_) {
      return true;
    }
  }
}
