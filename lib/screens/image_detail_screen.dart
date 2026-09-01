import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

class ImageDetailScreen extends StatefulWidget {
  final String imageUrl;

  const ImageDetailScreen({super.key, required this.imageUrl});

  @override
  State<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _bannerAd = AdMobService.createBannerAd();
      _bannerAd!.load();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (!kIsWeb && _bannerAd != null)
            SizedBox(
              height: 60,
              child: AdWidget(ad: _bannerAd!),
            ),
          Expanded(
            child: SafeArea(
              child: Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.contain,
                    // Full-screen viewer — 1080px is sufficient for all current
                    // Android screen resolutions while avoiding huge allocations.
                    memCacheWidth: 1080,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image, size: 48)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}