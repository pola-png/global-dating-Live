import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';
import '../services/storage_service.dart';
import '../services/timezone_service.dart';
import '../screens/image_detail_screen.dart';
import 'avatar_widget.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _ImageMetrics {
  final double displayHeight;
  final bool needsCrop;
  _ImageMetrics(this.displayHeight, this.needsCrop);
}


class _PostCardState extends State<PostCard> {
  Map<String, int> _reactions = {};
  String? _userReaction;

  final Map<String, Color> _bgColors = {
    'gray': const Color(0xFFF3F4F6),
    'white': Colors.white,
    'sky': const Color(0xFFBAE6FD),
    'rose': const Color(0xFFFCE7F3),
    'teal': const Color(0xFFB2F5EA),
    'amber': const Color(0xFFFEF3C7),
    'violet': const Color(0xFFE9D5FF),
    'black': Colors.black,
    'red': const Color(0xFFEF4444),
    'blue': const Color(0xFF3B82F6),
    'green': const Color(0xFF10B981),
  };

  final Map<String, Color> _textColors = {
    'gray': const Color(0xFF1F2937),
    'white': const Color(0xFF0A0A0A),
    'sky': const Color(0xFF1E3A8A),
    'rose': const Color(0xFF9F1239),
    'teal': const Color(0xFF134E4A),
    'amber': const Color(0xFF92400E),
    'violet': const Color(0xFF6B21A8),
    'black': Colors.white,
    'red': Colors.white,
    'blue': Colors.white,
    'green': Colors.white,
  };

  @override
  void initState() {
    super.initState();
    _reactions = {
      'like': widget.post['reactionsLike'] as int? ?? 0,
      'heart': widget.post['reactionsHeart'] as int? ?? 0,
      'laugh': widget.post['reactionsLaugh'] as int? ?? 0,
    };
  }

  DateTime? _parseAppwriteTimestamp(String timestamp) {
    try {
      // Handle Appwrite format: "01/13/2026 01:52:49.648 PM"
      final parts = timestamp.split(' ');
      if (parts.length >= 3) {
        final datePart = parts[0]; // "01/13/2026"
        final timePart = parts[1]; // "01:52:49.648"
        final amPm = parts[2]; // "PM"
        
        final dateComponents = datePart.split('/');
        final timeComponents = timePart.split(':');
        
        if (dateComponents.length == 3 && timeComponents.length >= 2) {
          final month = int.parse(dateComponents[0]);
          final day = int.parse(dateComponents[1]);
          final year = int.parse(dateComponents[2]);
          
          var hour = int.parse(timeComponents[0]);
          final minute = int.parse(timeComponents[1]);
          final secondParts = timeComponents[2].split('.');
          final second = int.parse(secondParts[0]);
          final millisecond = secondParts.length > 1 ? int.parse(secondParts[1].padRight(3, '0').substring(0, 3)) : 0;
          
          // Convert 12-hour to 24-hour format
          if (amPm.toUpperCase() == 'PM' && hour != 12) {
            hour += 12;
          } else if (amPm.toUpperCase() == 'AM' && hour == 12) {
            hour = 0;
          }
          
          return DateTime(year, month, day, hour, minute, second, millisecond);
        }
      }
      
      // Fallback to standard parsing
      return DateTime.parse(timestamp);
    } catch (e) {
      return null;
    }
  }

  Widget _buildTimeAgo(String createdAt) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 30), (i) => i),
      builder: (context, snapshot) {
        try {
          final now = DateTime.now();
          final postTime = DateTime.parse(createdAt).toLocal();
          final difference = now.difference(postTime);

          if (difference.isNegative || difference.inMinutes < 1) {
            return Text('Just now', style: Theme.of(context).textTheme.bodySmall);
          } else if (difference.inMinutes < 60) {
            return Text('${difference.inMinutes}m ago', style: Theme.of(context).textTheme.bodySmall);
          } else if (difference.inHours < 24) {
            return Text('${difference.inHours}h ago', style: Theme.of(context).textTheme.bodySmall);
          } else {
            return Text('${difference.inDays}d ago', style: Theme.of(context).textTheme.bodySmall);
          }
        } catch (e) {
          return Text('Just now', style: Theme.of(context).textTheme.bodySmall);
        }
      },
    );
  }

  Future<void> _toggleReaction(String reactionType) async {
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) {
        if (mounted) {
          Navigator.pushNamed(context, '/login');
        }
        return;
      }

      setState(() {
        if (_userReaction == reactionType) {
          _reactions[reactionType] = (_reactions[reactionType] ?? 0) - 1;
          _userReaction = null;
        } else {
          if (_userReaction != null) {
            _reactions[_userReaction!] = (_reactions[_userReaction!] ?? 0) - 1;
          }
          _reactions[reactionType] = (_reactions[reactionType] ?? 0) + 1;
          _userReaction = reactionType;
        }
      });

      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.postsCollectionId,
        documentId: widget.post['id'] as String,
        data: {
          'reactionsLike': _reactions['like'],
          'reactionsHeart': _reactions['heart'],
          'reactionsLaugh': _reactions['laugh'],
        },
      );
    } catch (_) {
      // Ignore reaction failures for now
    }
  }

  FontWeight _fontWeightForLength(int len) {
    if (len <= 40) return FontWeight.w800;
    if (len <= 100) return FontWeight.w700;
    if (len <= 200) return FontWeight.w600;
    return FontWeight.w400;
  }

  double _minHeightForLength(int len) {
    if (len <= 40) return 260;
    if (len <= 100) return 200;
    if (len <= 200) return 140;
    return 100;
  }

  double _fontSizeForLength(int len) {
    if (len <= 40) return 36.0;
    if (len <= 100) return 28.0;
    if (len <= 200) return 24.0;
    return 18.0;
  }

  Future<_ImageMetrics> _measureImage(String url, double maxHeight, double containerWidth) async {
    final completer = Completer<ImageInfo>();
    final provider = NetworkImage(url);
    final stream = provider.resolve(ImageConfiguration(size: Size(containerWidth, maxHeight)));
    late ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo info, bool sync) {
      completer.complete(info);
      stream.removeListener(listener);
    }, onError: (err, st) {
      if (!completer.isCompleted) completer.completeError(err);
      stream.removeListener(listener);
    });
    stream.addListener(listener);

    final info = await completer.future;
    final imgW = info.image.width.toDouble();
    final imgH = info.image.height.toDouble();
    final scale = containerWidth / imgW;
    final displayHeight = imgH * scale;
    final needsCrop = displayHeight > maxHeight;
    return _ImageMetrics(displayHeight, needsCrop);
  }

  // --- Caching to avoid re-resolving and re-measuring when scrolling ---
  static final Map<String, Future<String?>> _resolvedUrlFutures = {};
  static final Map<String, Future<_ImageMetrics>> _metricsFutures = {};
  static final Map<String, Future<Map<String, dynamic>?>> _profileFutures = {};

  Future<Map<String, dynamic>?> _getProfileCached(String userId) {
    if (_profileFutures.containsKey(userId)) return _profileFutures[userId]!;
    final fut = AppwriteService.databases.getDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.profilesCollectionId,
      documentId: userId,
    ).then((doc) => {'id': doc.$id, ...doc.data}).catchError((_) => <String, dynamic>{});
    _profileFutures[userId] = fut;
    return fut;
  }

  Future<String?> _getResolvedImageUrlCached(String key, dynamic imageValue) {
    if (_resolvedUrlFutures.containsKey(key)) return _resolvedUrlFutures[key]!;
    final fut = _resolveImageUrl(imageValue);
    _resolvedUrlFutures[key] = fut;
    return fut;
  }

  Future<_ImageMetrics> _getImageMetricsCached(String key, String url, double maxHeight, double containerWidth) {
    if (_metricsFutures.containsKey(key)) return _metricsFutures[key]!;
    final fut = _measureImage(url, maxHeight, containerWidth);
    _metricsFutures[key] = fut;
    return fut;
  }

  Future<String?> _resolveImageUrl(dynamic imageValue) async {
    if (imageValue == null) return null;
    try {
      // If imageValue is a list (e.g., multiple files), pick the first
      if (imageValue is List && imageValue.isNotEmpty) {
        imageValue = imageValue.first;
      }

      var url = imageValue.toString().trim();
      if (url.isEmpty) return null;

      // Prefer https for mobile platforms where cleartext may be blocked
      if (url.startsWith('http://')) {
        url = url.replaceFirst('http://', 'https://');
      }

      if (url.startsWith('http')) return url;

      // Otherwise treat as a file id and build Appwrite file view URL
      final public = StorageService.buildFileUrl(url);
      // ensure https
      final safe = public.startsWith('http://') ? public.replaceFirst('http://', 'https://') : public;
      return safe;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final author = widget.post['author'] as Map<String, dynamic>?;
    final bg = widget.post['backgroundColor'] as String?;
    final txt = widget.post['textColor'] as String?;
    // determine effective text color: prefer explicit `textColor`,
    // otherwise derive from `backgroundColor` when present
    final Color effectiveTextColor = _textColors[txt] ?? (bg != null ? _textColors[bg] ?? colorScheme.onSurface : colorScheme.onSurface);
    // resolve author name and avatar robustly (pick first non-empty value)
    String? pickFirstNonEmpty(List<dynamic> candidates) {
      for (final c in candidates) {
        if (c == null) continue;
        final s = c.toString().trim();
        if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
      }
      return null;
    }

    final String? authorName = pickFirstNonEmpty([
      author != null ? author['name'] : null,
      author != null ? author['username'] : null,
      widget.post['authorName'],
      widget.post['name'],
      widget.post['author_name'],
      widget.post['userName'],
      widget.post['user'],
    ]);

    final String? avatarRaw = pickFirstNonEmpty([
      author != null ? author['avatar'] : null,
      author != null ? author['photo'] : null,
      widget.post['authorAvatar'],
      widget.post['avatar'],
    ]);


    // Support multiple possible image fields saved by backend
    final dynamic imageValue = widget.post['imageUrl'] ?? widget.post['photoUrl'] ?? widget.post['photoPath'] ?? widget.post['photo_post'] ?? widget.post['photo'];
    final bool hasImage = imageValue != null;

    // Move authorId logic above widget tree
    final String? authorId = author != null
        ? (author['id'] ?? author['\$id'] ?? author['userId'] ?? author['uid'])?.toString()
        : (widget.post['authorId'] ?? widget.post['userId'] ?? widget.post['createdBy'])?.toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
              children: [
                if (authorId != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/profile/$authorId');
                      },
                      child: FutureBuilder<Map<String, dynamic>?>(
                        future: _getProfileCached(authorId),
                        builder: (context, profSnap) {
                          String? profName = authorName;
                          String avatarLetter = authorName?.isNotEmpty == true ? authorName![0].toUpperCase() : '?';
                          
                          if (profSnap.connectionState == ConnectionState.done && profSnap.hasData && profSnap.data != null) {
                            final p = profSnap.data!;
                            profName = (p['fullName'] ?? p['name'] ?? p['username'] ?? profName)?.toString();
                            avatarLetter = profName?.isNotEmpty == true ? profName![0].toUpperCase() : '?';
                          }
                          
                          return Row(
                            children: [
                              AvatarWidget(
                                avatarUrl: profSnap.data?['avatarPath'] as String?,
                                photos: profSnap.data?['photos'] != null ? List<String>.from(profSnap.data!['photos']) : null,
                                avatarLetter: avatarLetter,
                                radius: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (profName != null && profName.isNotEmpty) ...[
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(profName, style: Theme.of(context).textTheme.titleMedium),
                                          ),
                                          if (profSnap.data?['isBoosted'] == true) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.verified, color: Colors.blue, size: 16),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    _buildTimeAgo(widget.post['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  )
                else ...[
                  GestureDetector(
                    onTap: () {
                      // No authorId available, but still allow tap for consistency
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.purple,
                          child: Text(
                            authorName?.isNotEmpty == true ? authorName![0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (authorName != null && authorName.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(authorName, style: Theme.of(context).textTheme.titleMedium),
                                    ),
                                    if (widget.post['author']?['isBoosted'] == true) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified, color: Colors.blue, size: 16),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                              ],
                              _buildTimeAgo(widget.post['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
                if ((widget.post['text'] ?? widget.post['content']) != null)
              Builder(builder: (context) {
                final contentText = (widget.post['text'] ?? widget.post['content'] ?? '').toString().trim();
                final weight = _fontWeightForLength(contentText.length);
                final minH = _minHeightForLength(contentText.length);

                if (hasImage) {
                  // When an image is present, show text with no background or reserved color section
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Center(
                      child: Text(
                        contentText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: effectiveTextColor,
                          fontWeight: weight,
                          fontSize: _fontSizeForLength(contentText.length),
                        ),
                      ),
                    ),
                  );
                }

                final effectiveMinH = minH;
                return Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: effectiveMinH),
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _bgColors[bg] ?? Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    contentText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: effectiveTextColor,
                      fontWeight: weight,
                      fontSize: _fontSizeForLength(contentText.length),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        if (imageValue != null)
              FutureBuilder<String?>(
                future: _getResolvedImageUrlCached(widget.post['id']?.toString() ?? imageValue.toString(), imageValue),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(
                        height: 100,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    final imageUrl = snapshot.data;
                    if (imageUrl == null || imageUrl.isEmpty) {
                      return Container(
                        height: 100,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey[200]),
                        child: const Center(child: Icon(Icons.broken_image)),
                      );
                    }

                    // Decide whether to crop (show top, crop bottom) or shrink to fit
                    final screenH = MediaQuery.of(context).size.height;
                    final screenW = MediaQuery.of(context).size.width;
                    // account for horizontal margins/padding: card margin 12 + padding 12 each side
                    final containerWidth = screenW - 48.0;
                    final maxHeight = screenH * 0.5; // 50% of screen height

                    // use cached metrics future keyed by post id or url
                    final key = widget.post['id']?.toString() ?? imageUrl;
                    return FutureBuilder<_ImageMetrics>(
                      future: _getImageMetricsCached(key, imageUrl, maxHeight, containerWidth),
                      builder: (context, snapMetrics) {
                        if (snapMetrics.connectionState == ConnectionState.waiting) {
                          return SizedBox(height: 100, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                        }
                        if (snapMetrics.hasError || snapMetrics.data == null) {
                          return Container(
                            height: 100,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey[200]),
                            child: const Center(child: Icon(Icons.broken_image)),
                          );
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final metrics = snapMetrics.data!;
                            final actualHeight = metrics.displayHeight;
                            final useActualHeight = actualHeight <= maxHeight;

                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ImageDetailScreen(imageUrl: imageUrl),
                                ));
                              },
                              child: Container(
                                height: useActualHeight ? actualHeight : maxHeight,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imageUrl,
                                    width: double.infinity,
                                    height: useActualHeight ? actualHeight : maxHeight,
                                    fit: useActualHeight ? BoxFit.contain : BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: Colors.grey[200],
                                      child: const Center(child: Icon(Icons.broken_image)),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
              children: [
                IconButton(
                  icon: Icon(_userReaction == 'like' ? Icons.thumb_up : Icons.thumb_up_outlined),
                  onPressed: () => _toggleReaction('like'),
                ),
                Text('${_reactions['like'] ?? 0}'),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(_userReaction == 'heart' ? Icons.favorite : Icons.favorite_border),
                  onPressed: () => _toggleReaction('heart'),
                ),
                Text('${_reactions['heart'] ?? 0}'),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(Icons.emoji_emotions_outlined),
                  onPressed: () => _toggleReaction('laugh'),
                ),
                Text('${_reactions['laugh'] ?? 0}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}