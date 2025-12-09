import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../components/avatar_widget.dart';
import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';
import '../services/storage_service.dart';
import '../services/wallet_service.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isOwnProfile = false;
  int _coinBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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

      final targetUserId = widget.userId ?? currentUserId;
      _isOwnProfile = targetUserId == currentUserId;

      final doc = await AppwriteService.databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: targetUserId,
      );
      final profileResponse = {
        ...doc.data,
        'id': doc.$id,
      };

      if (mounted) {
        final coins = await WalletService.getBalance();
        setState(() {
          _profile = profileResponse;
          _isLoading = false;
          _coinBalance = coins;
        });
      }
    } catch (e) {
      // If profile document doesn't exist yet, create a minimal one and retry once.
      if (e is AppwriteException && e.code == 404) {
        try {
          final user = await AppwriteService.account.get();
          final userId = user.$id;
          final email = user.email;
          final fullName = user.name ?? 'New User';

          await AppwriteService.databases.createDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.profilesCollectionId,
            documentId: userId,
            data: {
              'userId': userId,
              'email': email,
              'fullName': fullName,
              'age': 18,
              'gender': 'Prefer not to say',
              'country': '',
              'countryCode': '',
              'city': '',
              'lookingFor': '',
              'relationshipStatus': '',
              'about': '',
              'avatarLetter': fullName.isNotEmpty
                  ? fullName[0].toUpperCase()
                  : 'U',
              'photos': <String>[],
              'joinedGroups': <String>[],
              'coinBalance': 0,
              'isBoosted': false,
              'boostedUntil': null,
              'isVerified': false,
              'createdAt': DateTime.now().toIso8601String(),
              'avatarPath': null,
            },
          );
          // Retry load once now that profile exists.
          await _loadProfile();
          return;
        } catch (_) {
          // Fall through to not-found state.
        }
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startChat() async {
    if (_profile == null) return;

    try {
      final currentUserId = await SessionStore.ensureUserId();
      if (currentUserId == null) return;

      final otherUserId = _profile!['id'] as String;

      final db = AppwriteService.databases;

      final direct = await db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatRoomsCollectionId,
        queries: [
          Query.equal('user1Id', currentUserId),
          Query.equal('user2Id', otherUserId),
        ],
      );

      final inverse = await db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatRoomsCollectionId,
        queries: [
          Query.equal('user1Id', otherUserId),
          Query.equal('user2Id', currentUserId),
        ],
      );

      var chatRoomDoc = direct.documents.isNotEmpty
          ? direct.documents.first
          : (inverse.documents.isNotEmpty ? inverse.documents.first : null);

      if (chatRoomDoc == null) {
        chatRoomDoc = await db.createDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.chatRoomsCollectionId,
          documentId: ID.unique(),
          data: {
            'user1Id': currentUserId,
            'user2Id': otherUserId,
            'lastMessageId': null,
            'lastActive': DateTime.now().toIso8601String(),
          },
        );
      }

      final chatRoomId = chatRoomDoc.$id;

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
        const SnackBar(content: Text('Not enough coins to boost (50 coins needed).')),
      );
      return;
    }

    try {
      final userId = await SessionStore.ensureUserId();
      if (userId != null) {
        await AppwriteService.databases.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.profilesCollectionId,
          documentId: userId,
          data: {
            'isBoosted': true,
            'isVerified': true,
            'boostedUntil': DateTime.now()
                .add(const Duration(days: 14))
                .toIso8601String(),
          },
        );
      }
      await _refreshCoins();
      await _loadProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile boosted and verified!')),
      );
    } catch (_) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark boost on server, but coins deducted locally.')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isOwnProfile ? 'My Profile' : (_profile?['fullName'] ?? 'Profile')),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: _isOwnProfile ? BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
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
      body: _isLoading
          ? _buildLoadingState()
          : _profile == null
              ? _buildNotFoundState()
              : _buildProfileContent(),
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

  Widget _buildProfileContent() {
    final firstName = _profile!['fullName'].toString().split(' ')[0];
    final boostActive = _isBoostActive(_profile!);
    final isVerified = _profile!['isVerified'] == true;
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Colors.grey[50],
            child: Column(
              children: [
                Text(
                  _isOwnProfile 
                      ? 'This is how others see you.' 
                      : 'View $firstName\'s profile.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 24),
                // Avatar with VIP badge
                AvatarWidget(
                  avatarUrl: _profile!['avatarPath'],
                  photos: _profile!['photos'] != null ? List<String>.from(_profile!['photos']) : null,
                  avatarLetter: _profile!['avatarLetter'] ?? 'U',
                  radius: 60,
                  showVipBadge: false,
                ),
                const SizedBox(height: 16),
                Text(
                  _profile!['fullName'] ?? 'Unknown User',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                if (isVerified || boostActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Chip(
                      avatar: const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 16),
                      backgroundColor: Colors.green,
                      label: Text(
                        boostActive && isVerified
                            ? 'Verified & Boosted'
                            : boostActive
                                ? 'Boosted'
                                : 'Verified',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                // Action buttons
                if (_isOwnProfile)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/profile/edit'),
                          icon: const Icon(LucideIcons.edit),
                          label: const Text('Edit Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/coins'),
                          icon: const Icon(LucideIcons.badgeDollarSign, color: Colors.green),
                          label: Text('Buy Coins ($_coinBalance)'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: boostActive ? null : _boostProfile,
                          icon: const Icon(LucideIcons.zap),
                          label: Text(
                            boostActive
                                ? 'Boosted (14 days)'
                                : 'Boost Profile (50 coins)',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startChat,
                          icon: const Icon(LucideIcons.messageCircle),
                          label: const Text('Send Message'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Profile content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // About Me card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(LucideIcons.user, color: Color(0xFF666666)),
                            SizedBox(width: 8),
                            Text(
                              'About Me',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _profile!['about'] ?? 'No bio available',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Details card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(LucideIcons.list, color: Color(0xFF666666)),
                            SizedBox(width: 8),
                            Text(
                              'Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailGrid(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Photo Gallery
                if (_isOwnProfile || (_profile!['photos'] != null && (_profile!['photos'] as List).isNotEmpty))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(LucideIcons.image, color: Color(0xFF666666)),
                              SizedBox(width: 8),
                              Text(
                                'My Gallery',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if ((_profile!['photos'] as List?)?.isNotEmpty ?? false) ...[  
                            const SizedBox(height: 12),
                            GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1,
                            ),
                            itemCount: (_profile!['photos'] as List).length,
                            itemBuilder: (context, index) {
                              final photoId = (_profile!['photos'] as List)[index] as String;
                              final photoUrl =
                                  StorageService.buildFileUrl(photoId);
                              return GestureDetector(
                                onTap: () => _showPhotoGallery(index),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: photoUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[300],
                                      child: const Icon(LucideIcons.image, color: Colors.grey),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.grey[300],
                                      child: const Icon(LucideIcons.imageOff, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          ] else if (_isOwnProfile)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'No photos yet. Add some photos to your profile!',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (_isOwnProfile) ...[  
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/profile/photos'),
                              icon: const Icon(LucideIcons.image),
                              label: const Text('Manage Photos'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (_isOwnProfile) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/policy'),
                    icon: const Icon(LucideIcons.fileText),
                    label: const Text('Privacy Policy'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await AppwriteService.account.deleteSession(
                        sessionId: 'current',
                      );
                      SessionStore.clear();
                      if (mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                    icon: const Icon(LucideIcons.logOut),
                    label: const Text('Log Out'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Account'),
                          content: const Text('Are you sure? This action cannot be undone. All your data will be permanently deleted.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  final userId = await SessionStore.ensureUserId();
                                  if (userId != null) {
                                    await AppwriteService.databases.deleteDocument(
                                      databaseId: AppwriteConfig.databaseId,
                                      collectionId: AppwriteConfig.profilesCollectionId,
                                      documentId: userId,
                                    );
                                    await AppwriteService.account.deleteSession(
                                      sessionId: 'current',
                                    );
                                    SessionStore.clear();
                                    if (mounted) {
                                      Navigator.pushReplacementNamed(context, '/login');
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to delete account')),
                                    );
                                  }
                                }
                              },
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
        childAspectRatio: 3,
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
              color: const Color(0xFF666666),
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
