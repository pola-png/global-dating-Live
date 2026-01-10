import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/storage_service.dart';

class AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final List<String>? photos;
  final String avatarLetter;
  final double radius;
  final bool showVipBadge;
  final VoidCallback? onTap;

  const AvatarWidget({
    super.key,
    this.avatarUrl,
    this.photos,
    required this.avatarLetter,
    this.radius = 25,
    this.showVipBadge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: Theme.of(context).primaryColor,
            backgroundImage: (photos != null && photos!.isNotEmpty)
                ? CachedNetworkImageProvider(
                    StorageService.buildFileUrl(photos!.first),
                  )
                : (avatarUrl != null && avatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(
                        StorageService.getAvatarUrl(avatarUrl, avatarLetter),
                      )
                    : null),
            child: (photos == null || photos!.isEmpty) && (avatarUrl == null || avatarUrl!.isEmpty)
                ? Text(
                    avatarLetter,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: radius * 0.6,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          if (showVipBadge)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star,
                  color: Colors.white,
                  size: radius * 0.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
