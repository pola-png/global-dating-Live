import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:country_picker/country_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/supabase_service.dart';
import '../services/subscription_service.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  List<Country> _allCountries = [];
  List<Country> _filteredCountries = [];
  final Map<String, int> _groupMetadata = {};
  Set<String> _joinedGroups = {};
  bool _isLoading = true;

  final List<String> _priorityCountries = ['United States', 'United Kingdom', 'Canada'];

  @override
  bool get wantKeepAlive => true;

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

      final profileDoc = await SupabaseService.client
          .from('users')
          .select('joined_groups')
          .eq('id', userId)
          .maybeSingle();

      _joinedGroups = Set<String>.from(
          profileDoc?['joined_groups'] ?? <String>[]);

      final metadataRes = await SupabaseService.client
          .from('group_metadata')
          .select('*');

      for (final doc in metadataRes) {
        final slug = doc['country_slug'] as String;
        final count = doc['member_count'] as int? ?? 0;
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
    final plan = SubscriptionService.currentPlan;
    if (plan == SubscriptionPlan.none || plan == SubscriptionPlan.basic) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Upgrade Required'),
            content: const Text("Your subscription plan doesn't allow joining groups. Upgrade to a higher plan to have access."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
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

    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) return;

      final slug = _getCountrySlug(country.name);
      final newJoinedGroups = [..._joinedGroups, slug];

      await SupabaseService.client
          .from('users')
          .update({'joined_groups': newJoinedGroups})
          .eq('id', userId);

      final currentCount = _groupMetadata[slug] ?? 0;

      final existing = await SupabaseService.client
          .from('group_metadata')
          .select('*')
          .eq('country_slug', slug)
          .maybeSingle();

      if (existing != null) {
        await SupabaseService.client
            .from('group_metadata')
            .update({'member_count': currentCount + 1})
            .eq('country_slug', slug);
      } else {
        await SupabaseService.client.from('group_metadata').insert({
          'country_name': country.name,
          'country_slug': slug,
          'member_count': currentCount + 1,
        });
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
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Country Groups'),
        backgroundColor: colorScheme.surfaceContainer,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surfaceContainer,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
          // Modern header section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary.withOpacity(0.1), colorScheme.surface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LucideIcons.globe,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Find Your Community',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connect with people from your country',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Modern search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for a country group...',
                    prefixIcon: const Icon(LucideIcons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Groups grid
          Expanded(
            child: _isLoading
                ? _buildModernLoadingGrid()
                : _buildModernGroupsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(context),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.70,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernGroupsGrid() {
    if (_filteredCountries.isEmpty) {
      return _buildEmptyState();
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(context),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.65,
      ),
      itemCount: _filteredCountries.length,
      itemBuilder: (context, index) {
        final country = _filteredCountries[index];
        return _buildModernGroupCard(country);
      },
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.search,
                size: 48,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No groups found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Try adjusting your search or check back later for new country groups.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                _filterCountries();
              },
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('Clear Search'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernGroupCard(Country country) {
    final slug = _getCountrySlug(country.name);
    final memberCount = _groupMetadata[slug] ?? 0;
    final hasJoined = _joinedGroups.contains(slug);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasJoined 
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.outline.withOpacity(0.2),
          width: hasJoined ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (hasJoined) {
            Navigator.pushNamed(context, '/groups/$slug', arguments: country);
          } else {
            _joinGroup(country);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Country flag with modern styling
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: 'https://flagsapi.com/${country.countryCode}/flat/64.png',
                    fit: BoxFit.cover,
                    // Flag icons are small — 128px is more than sufficient.
                    memCacheWidth: 128,
                    memCacheHeight: 128,
                    placeholder: (context, url) => Container(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        LucideIcons.flag,
                        color: colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Country name
              Text(
                country.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 6),
              
              // Member count with modern styling
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.users,
                      size: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$memberCount members',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Modern action button
              SizedBox(
                width: double.infinity,
                child: hasJoined
                    ? FilledButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/groups/$slug', arguments: country),
                        icon: const Icon(LucideIcons.messageCircle, size: 18),
                        label: const Text('Chat'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => _joinGroup(country),
                        icon: const Icon(LucideIcons.plus, size: 18),
                        label: const Text('Join'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 2;
    if (width < 900) return 3;
    return 4;
  }
}
