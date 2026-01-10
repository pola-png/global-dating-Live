import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/appwrite_config.dart';
import '../config/admin_config.dart';
import '../services/appwrite_service.dart';
import '../services/storage_service.dart';

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
  }

  Future<void> _checkAdminAndLoad() async {
    final userId = await SessionStore.ensureUserId();
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final profileDoc = await AppwriteService.databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
      );
      // Check if user is admin by ID or isAdmin field
      final isAdmin = profileDoc.data['isAdmin'] == true || userId == AdminConfig.adminUserId;
      setState(() => _isAdmin = isAdmin);
      if (isAdmin) {
        _loadSessions();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSessions() async {
    try {
      final res = await AppwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.supportSessionsCollectionId,
        queries: [
          Query.equal('type', 'fast_match'),
          Query.orderDesc('createdAt'),
        ],
      );

      final sessions = <Map<String, dynamic>>[];
      for (final doc in res.documents) {
        final session = {...doc.data, 'id': doc.$id};
        
        // Load user profile
        try {
          final userDoc = await AppwriteService.databases.getDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.profilesCollectionId,
            documentId: session['userId'],
          );
          session['userProfile'] = userDoc.data;
        } catch (_) {}
        
        sessions.add(session);
      }

      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _closeSession(String sessionId) async {
    try {
      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.supportSessionsCollectionId,
        documentId: sessionId,
        data: {'status': 'closed'},
      );
      _loadSessions();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Support'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Access Denied: Admin Only'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fast Match Support Dashboard'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loadSessions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.inbox, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'No fast match requests yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.red.shade50,
                      child: Row(
                        children: [
                          const Icon(LucideIcons.info, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Admin Dashboard',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  '${_sessions.length} total requests • Tap to chat • Long-press to close',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          final profile = session['userProfile'] ?? {};
                          final status = session['status'] ?? 'open';
                          final createdAt = DateTime.parse(session['createdAt']);
                          final photos = profile['photos'] as List?;
                          final avatarUrl = (photos != null && photos.isNotEmpty)
                              ? StorageService.buildFileUrl(photos.first)
                              : null;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: avatarUrl != null
                                  ? CircleAvatar(
                                      radius: 28,
                                      backgroundImage: CachedNetworkImageProvider(avatarUrl),
                                    )
                                  : CircleAvatar(
                                      radius: 28,
                                      backgroundColor: status == 'open' ? Colors.green : Colors.grey,
                                      child: Text(
                                        (profile['avatarLetter'] ?? 'U').toString(),
                                        style: const TextStyle(color: Colors.white, fontSize: 20),
                                      ),
                                    ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      profile['fullName'] ?? 'Unknown User',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(status.toUpperCase()),
                                    backgroundColor: status == 'open' ? Colors.green : Colors.grey,
                                    labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(LucideIcons.user, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text('${profile['age'] ?? 'N/A'} • ${profile['gender'] ?? 'N/A'}'),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(LucideIcons.mapPin, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text('${profile['city'] ?? 'N/A'}, ${profile['country'] ?? 'N/A'}'),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(LucideIcons.heart, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Looking for: ${profile['lookingFor'] ?? 'N/A'}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Requested: ${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                              trailing: const Icon(LucideIcons.messageCircle, color: Colors.blue),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/chat/${session['chatRoomId']}',
                                  arguments: {
                                    'chatRoom': {'id': session['chatRoomId']},
                                    'otherUser': {
                                      'id': session['userId'],
                                      'fullName': profile['fullName'],
                                      'avatarLetter': profile['avatarLetter'],
                                    },
                                  },
                                );
                              },
                              onLongPress: status == 'open'
                                  ? () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Close Session?'),
                                          content: Text('Mark ${profile['fullName']}\'s fast match session as closed?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _closeSession(session['id']);
                                              },
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              child: const Text('Close Session'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
