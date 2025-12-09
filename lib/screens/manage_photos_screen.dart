import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../components/responsive_page.dart';
import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';
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

      final doc = await AppwriteService.databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
      );

      setState(() {
        _photos = List<String>.from(doc.data['photos'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    if (_photos.length >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 3 photos allowed')),
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

      final extension = _inferExtension(image);
      final file = await AppwriteService.storage.createFile(
        bucketId: AppwriteConfig.mediaBucketId,
        fileId: ID.unique(),
        file: InputFile.fromBytes(
          bytes: bytes,
          filename:
              '$userId-profile-${DateTime.now().millisecondsSinceEpoch}.$extension',
        ),
      );

      final fileId = file.$id;

      final updatedPhotos = [..._photos, fileId];
      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
        data: {'photos': updatedPhotos},
      );

      await AppwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.postsCollectionId,
        documentId: ID.unique(),
        data: {
          'authorId': userId,
          'text': '',
          'backgroundColor': 'white',
          'textColor': '#000000',
          'isCentered': false,
          'createdAt': DateTime.now().toIso8601String(),
          'reactionsLike': 0,
          'reactionsHeart': 0,
          'reactionsLaugh': 0,
          'type': 'photo_post',
          'photoPath': fileId,
          'photoUrl': null,
        },
      );

      setState(() {
        _photos = updatedPhotos;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded and posted to feed')),
        );
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

      await AppwriteService.storage.deleteFile(
        bucketId: AppwriteConfig.mediaBucketId,
        fileId: fileId,
      );

      // Remove any feed posts that referenced this photo
      final postsRes = await AppwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.postsCollectionId,
        queries: [
          Query.equal('authorId', userId),
          Query.equal('photoPath', fileId),
        ],
      );

      for (final doc in postsRes.documents) {
        await AppwriteService.databases.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.postsCollectionId,
          documentId: doc.$id,
        );
      }

      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
        data: {'photos': updatedPhotos},
      );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Photos'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsivePage(
              maxWidth: 1100,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload up to 3 photos (${_photos.length}/3)',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = _gridCountForWidth(constraints.maxWidth);
                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _photos.length + (_photos.length < 3 ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < _photos.length) {
                              final photoId = _photos[index];
                              final photoUrl =
                                  StorageService.buildFileUrl(photoId);
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: IconButton(
                                      onPressed: () => _deletePhoto(index),
                                      icon: const Icon(LucideIcons.trash2),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return GestureDetector(
                                onTap: _isUploading ? null : _pickImage,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: _isUploading
                                      ? const Center(child: CircularProgressIndicator())
                                      : const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(LucideIcons.plus, size: 48, color: Colors.grey),
                                            SizedBox(height: 8),
                                            Text('Add Photo', style: TextStyle(color: Colors.grey)),
                                          ],
                                        ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _inferExtension(XFile file) {
    final name = file.name.toLowerCase();
    final path = file.path.toLowerCase();
    if (name.contains('.')) return name.split('.').last;
    if (path.contains('.')) return path.split('.').last;
    return 'jpg';
  }

  int _gridCountForWidth(double width) {
    if (width > 1000) return 4;
    if (width > 750) return 3;
    return 2;
  }
}
