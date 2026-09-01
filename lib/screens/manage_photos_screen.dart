import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:cached_network_image/cached_network_image.dart';

import '../components/responsive_page.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';

class ManagePhotosScreen extends StatefulWidget {
  const ManagePhotosScreen({super.key});

  @override
  State<ManagePhotosScreen> createState() => _ManagePhotosScreenState();
}

class _ManagePhotosScreenState extends State<ManagePhotosScreen> {
  List<String> _photos = [];
  bool _isLoading = true;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) return;

      final doc = await SupabaseService.client
          .from('users')
          .select('photos')
          .eq('id', userId)
          .maybeSingle();

      setState(() {
        _photos = List<String>.from(doc?['photos'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    if (_photos.length >= 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 6 photos allowed')),
        );
      }
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);
      final bytes = await image.readAsBytes();

      // Check for inappropriate content
      if (!await _isImageAppropriate(bytes)) {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This photo violates our content policy. Please upload appropriate images only.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final userId = await SessionStore.ensureUserId();
      if (userId == null) return;

      final fileId = await StorageService.uploadPhoto(userId, image);

      if (fileId != null) {
        final updatedPhotos = [..._photos, fileId];
        await SupabaseService.client
            .from('users')
            .update({'photos': updatedPhotos})
            .eq('id', userId);

        await SupabaseService.client.from('posts').insert({
          'author_id': userId,
          'text': null,
          'is_centered': false,
          'created_at': DateTime.now().toIso8601String(),
          'reactions_like': 0,
          'reactions_heart': 0,
          'reactions_laugh': 0,
          'type': 'photo_post',
          'photo_path': fileId,
        });

        setState(() {
          _photos = updatedPhotos;
          _isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo uploaded and posted to feed')),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    }
  }

  Future<bool> _isImageAppropriate(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return true;

      // Resize to 224x224 for model input
      final resized = img.copyResize(image, width: 224, height: 224);
      
      // Check for skin tone pixels (simple heuristic)
      int skinPixels = 0;
      int totalPixels = resized.width * resized.height;
      
      for (int y = 0; y < resized.height; y++) {
        for (int x = 0; x < resized.width; x++) {
          final pixel = resized.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          
          // Skin tone detection heuristic
          if (r > 95 && g > 40 && b > 20 &&
              r > g && r > b &&
              (r - g).abs() > 15 &&
              r - b > 15) {
            skinPixels++;
          }
        }
      }
      
      final skinRatio = skinPixels / totalPixels;
      // If more than 60% skin tone, likely inappropriate
      return skinRatio < 0.6;
    } catch (e) {
      // If detection fails, allow the image
      return true;
    }
  }

  Future<void> _deletePhoto(int index) async {
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) return;

      final fileId = _photos[index];
      final updatedPhotos = List<String>.from(_photos);
      updatedPhotos.removeAt(index);

      await StorageService.deletePhoto(fileId);

      // Remove any feed posts that referenced this photo
      await SupabaseService.client
          .from('posts')
          .delete()
          .eq('author_id', userId)
          .eq('photo_path', fileId);

      await SupabaseService.client
          .from('users')
          .update({'photos': updatedPhotos})
          .eq('id', userId);

      setState(() {
        _photos = updatedPhotos;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete photo: $e')),
        );
      }
    }
  }

  String _inferExtension(XFile file) {
    final name = file.name.toLowerCase();
    final path = file.path.toLowerCase();
    if (name.contains('.')) return name.split('.').last;
    if (path.contains('.')) return path.split('.').last;
    return 'jpg';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Manage Photos'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsivePage(
              maxWidth: 800,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Photos (${_photos.length}/6)',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Showcase your personality. Clear, friendly photos get more connections.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  if (_isUploading)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 16),
                            Text('Analyzing and uploading photo...'),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _photos.length < 6 ? _photos.length + 1 : 6,
                      itemBuilder: (context, index) {
                        if (index == _photos.length) {
                          return InkWell(
                            onTap: _pickImage,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.2),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: const Icon(
                                LucideIcons.plus,
                                size: 32,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }

                        final photoPath = _photos[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: StorageService.buildFileUrl(photoPath),
                                fit: BoxFit.cover,
                                // Manage-photos grid thumbnails — cap at 400px.
                                memCacheWidth: 400,
                                placeholder: (context, url) => Container(
                                  color: colorScheme.surfaceVariant,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: colorScheme.surfaceVariant,
                                  child: const Icon(LucideIcons.image),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: InkWell(
                                  onTap: () => _deletePhoto(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      LucideIcons.trash2,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
