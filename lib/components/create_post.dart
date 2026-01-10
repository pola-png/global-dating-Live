import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';

import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';

class CreatePost extends StatefulWidget {
  final Function(Map<String, dynamic>) onPostCreated;

  const CreatePost({super.key, required this.onPostCreated});

  @override
  State<CreatePost> createState() => _CreatePostState();
}

class _CreatePostState extends State<CreatePost> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isExpanded = false;
  bool _isPosting = false;
  String _selectedBgColor = 'white';


  final Map<String, Map<String, dynamic>> _colorThemes = {
    'gray': {'bg': Colors.grey[200], 'text': Colors.grey[800]},
    'white': {'bg': Colors.white, 'text': Colors.black},
    'sky': {'bg': Colors.lightBlue[200], 'text': Colors.lightBlue[800]},
    'rose': {'bg': Colors.pink[200], 'text': Colors.pink[800]},
    'teal': {'bg': Colors.teal[200], 'text': Colors.teal[800]},
    'amber': {'bg': Colors.amber[200], 'text': Colors.amber[800]},
    'violet': {'bg': Colors.purple[200], 'text': Colors.purple[800]},
    'black': {'bg': Colors.black, 'text': Colors.white},
    'red': {'bg': Colors.red[500], 'text': Colors.white},
    'blue': {'bg': Colors.blue[500], 'text': Colors.white},
    'green': {'bg': Colors.green[500], 'text': Colors.white},
  };

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {}); // Rebuild to update button state
    });
  }

  Future<Map<String, dynamic>?> _getUserProfile() async {
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) return null;

      final doc = await AppwriteService.databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
      );
      return doc.data;
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    if (_textController.text.trim().isEmpty) return;

    final userId = await SessionStore.ensureUserId();
    if (userId == null) {
      if (mounted) {
        Navigator.pushNamed(context, '/login');
      }
      return;
    }

    setState(() => _isPosting = true);

    try {
      final db = AppwriteService.databases;

      final profileDoc = await db.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
      );

      final createdAt = DateTime.now().toIso8601String();

      final postDoc = await db.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.postsCollectionId,
        documentId: ID.unique(),
        data: {
          'authorId': userId,
          'text': _textController.text.trim(),
          'backgroundColor': _selectedBgColor,
          'textColor': _colorThemes[_selectedBgColor]!['text']
              .toString(),
          'isCentered': true,
          'createdAt': createdAt,
          'reactionsLike': 0,
          'reactionsHeart': 0,
          'reactionsLaugh': 0,
          'type': 'text_post',
          'photoUrl': null,
          'photoPath': null,
        },
      );

      final postData = {
        ...postDoc.data,
        'id': postDoc.$id,
        'author': {
          ...profileDoc.data,
          'id': profileDoc.$id,
        },
      };

      widget.onPostCreated(postData);

      _textController.clear();
      setState(() {
        _isExpanded = false;
        _selectedBgColor = 'white';

      });
      _focusNode.unfocus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your post has been shared.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create post. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = _colorThemes[_selectedBgColor]!;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<Map<String, dynamic>?>(
                  future: _getUserProfile(),
                  builder: (context, snapshot) {
                    final avatarLetter =
                        snapshot.data?['avatarLetter'] ?? 'U';
                    return CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFFF6B6B),
                      child: Text(
                        avatarLetter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: currentTheme['bg'],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      onTap: () {
                        if (!_isExpanded) {
                          setState(() => _isExpanded = true);
                        }
                      },
                      maxLines: _isExpanded ? 5 : 1,
                      minLines: _isExpanded ? 3 : 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: currentTheme['text']),
                      decoration: const InputDecoration(
                        hintText: "What's on your mind?",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              // Color palette
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _colorThemes.keys.map((colorKey) {
                    final isSelected = _selectedBgColor == colorKey;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedBgColor = colorKey),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _colorThemes[colorKey]!['bg'],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFFFF6B6B) : Colors.grey[300]!,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              // Controls
              Row(
                children: [
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _textController.text.trim().isEmpty || _isPosting
                        ? null
                        : _createPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: Colors.white,
                    ),
                    child: _isPosting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Post'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
