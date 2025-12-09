import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/storage_service.dart';
import '../components/responsive_page.dart';
import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';

class PhotoManagerScreen extends StatefulWidget {
  const PhotoManagerScreen({super.key});

  @override
  State<PhotoManagerScreen> createState() => _PhotoManagerScreenState();
}

class _PhotoManagerScreenState extends State<PhotoManagerScreen> {
  List<String> _photos = [];
  bool _isLoading = true;
  bool _isUploading = false;

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

      if (mounted) {
        setState(() {
          _photos = List<String>.from(doc.data['photos'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 6 photos allowed')),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    if (mounted) {
      setState(() => _isUploading = true);
    }

    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) return;

      final photoId = await StorageService.uploadPhoto(userId, image);
      
      if (photoId != null) {
        final updatedPhotos = [..._photos, photoId];
        
        await AppwriteService.databases.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.profilesCollectionId,
          documentId: userId,
          data: {'photos': updatedPhotos},
        );

        if (mounted) {
          setState(() {
            _photos = updatedPhotos;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo uploaded successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload photo')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deletePhoto(int index) async {
    final photoId = _photos[index];
    
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) return;

      await StorageService.deletePhoto(photoId);
      
      final updatedPhotos = List<String>.from(_photos)..removeAt(index);
      
      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: userId,
        data: {'photos': updatedPhotos},
      );

      if (mounted) {
        setState(() {
          _photos = updatedPhotos;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete photo')),
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
                    'Your Photos (${_photos.length}/6)',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add up to 6 photos to showcase yourself',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = _gridCountForWidth(constraints.maxWidth);
                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: _photos.length + (_photos.length < 6 ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _photos.length) {
                              return _buildAddPhotoCard();
                            }
                            return _buildPhotoCard(index);
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

  Widget _buildAddPhotoCard() {
    return Card(
      child: InkWell(
        onTap: _isUploading ? null : _addPhoto,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isUploading)
                const CircularProgressIndicator()
              else ...[
                Icon(
                  LucideIcons.plus,
                  size: 48,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add Photo',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard(int index) {
    return Card(
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: _photos[index],
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Icon(LucideIcons.imageOff, color: Colors.grey),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(LucideIcons.trash2, color: Colors.white, size: 20),
                onPressed: () => _showDeleteDialog(index),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePhoto(index);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  int _gridCountForWidth(double width) {
    if (width > 1100) return 4;
    if (width > 800) return 3;
    return 2;
  }
}
