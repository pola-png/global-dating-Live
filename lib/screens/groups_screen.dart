import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:country_picker/country_picker.dart';

import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _searchController = TextEditingController();
  List<Country> _allCountries = [];
  List<Country> _filteredCountries = [];
  final Map<String, int> _groupMetadata = {};
  Set<String> _joinedGroups = {};
  bool _isLoading = true;

  final List<String> _priorityCountries = ['United States', 'United Kingdom', 'Canada'];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterCountries);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      final db = AppwriteService.databases;

      final profileDoc = await db.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
      );

      _joinedGroups =
          Set<String>.from(profileDoc.data['joinedGroups'] ?? <String>[]);

      final metadataRes = await db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.groupMetadataCollectionId,
      );

      for (final doc in metadataRes.documents) {
        final data = doc.data;
        final slug = data['countrySlug'] as String;
        final count = data['memberCount'] as int? ?? 0;
        _groupMetadata[slug] = count;
      }

      // Get all countries and sort them
      _allCountries = CountryService().getAll();
      _sortCountries();
      _filteredCountries = List.from(_allCountries);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _sortCountries() {
    _allCountries.sort((a, b) {
      final aPriority = _priorityCountries.indexOf(a.name);
      final bPriority = _priorityCountries.indexOf(b.name);
      
      if (aPriority != -1 && bPriority != -1) {
        return aPriority.compareTo(bPriority);
      } else if (aPriority != -1) {
        return -1;
      } else if (bPriority != -1) {
        return 1;
      } else {
        return a.name.compareTo(b.name);
      }
    });
  }

  void _filterCountries() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCountries = _allCountries
          .where((country) => country.name.toLowerCase().contains(query))
          .toList();
    });
  }

  String _getCountrySlug(String countryName) {
    return countryName.toLowerCase().replaceAll(' ', '-');
  }

  Future<void> _joinGroup(Country country) async {
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) return;

      final db = AppwriteService.databases;

      final slug = _getCountrySlug(country.name);
      final newJoinedGroups = [..._joinedGroups, slug];

      await db.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
        data: {
          'joinedGroups': newJoinedGroups,
        },
      );

      final currentCount = _groupMetadata[slug] ?? 0;

      final existing = await db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.groupMetadataCollectionId,
        queries: [
          Query.equal('countrySlug', slug),
        ],
      );

      if (existing.documents.isNotEmpty) {
        final doc = existing.documents.first;
        await db.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.groupMetadataCollectionId,
          documentId: doc.$id,
          data: {
            'memberCount': currentCount + 1,
          },
        );
      } else {
        await db.createDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.groupMetadataCollectionId,
          documentId: ID.unique(),
          data: {
            'groupId': DateTime.now().millisecondsSinceEpoch,
            'groupName': country.name,
            'countrySlug': slug,
            'memberCount': currentCount + 1,
            'createdAt': DateTime.now().toIso8601String(),
            'description': null,
            'groupAvatarUrl': null,
          },
        );
      }

      if (mounted) {
        setState(() {
          _joinedGroups.add(slug);
          _groupMetadata[slug] = currentCount + 1;
        });

        Navigator.pushNamed(context, '/groups/$slug', arguments: country);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to join group')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Country Groups'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        currentIndex: 1,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              // Already on groups
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
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find your community and connect with people from your country.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 16),
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for a country group...',
                    prefixIcon: const Icon(LucideIcons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Groups grid
          Expanded(
            child: _isLoading
                ? _buildLoadingGrid()
                : _buildGroupsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(context),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return Card(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 16,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 12,
                  color: Colors.grey[300],
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  height: 36,
                  color: Colors.grey[300],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(context),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: _filteredCountries.length,
      itemBuilder: (context, index) {
        final country = _filteredCountries[index];
        return _buildGroupCard(country);
      },
    );
  }

  Widget _buildGroupCard(Country country) {
    final slug = _getCountrySlug(country.name);
    final memberCount = _groupMetadata[slug] ?? 0;
    final hasJoined = _joinedGroups.contains(slug);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Country flag
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: NetworkImage(
                    'https://flagsapi.com/${country.countryCode}/flat/64.png',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Country name
            Text(
              country.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Member count
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.users, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '$memberCount members',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Join/Visit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (hasJoined) {
                    Navigator.pushNamed(context, '/groups/$slug', arguments: country);
                  } else {
                    _joinGroup(country);
                  }
                },
                icon: Icon(hasJoined ? LucideIcons.checkCircle : LucideIcons.users),
                label: Text(hasJoined ? 'Visit' : 'Join Group'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasJoined ? Colors.green : Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 1;
    if (width < 900) return 2;
    return 3;
  }
}
