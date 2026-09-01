import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A wrapper around [CachedNetworkImage] that enforces bitmap downsampling
/// via [memCacheWidth] / [memCacheHeight].
///
/// Downsampling prevents Android from decoding full-resolution bitmaps into
/// memory when the image is displayed at a much smaller size, which resolves
/// the Google Play "Improve your app's performance with bitmap downsampling"
/// recommendation.
///
/// Usage:
/// ```dart
/// DownsampledNetworkImage(
///   imageUrl: url,
///   fit: BoxFit.cover,
///   cacheWidth: 600,  // logical px, not physical
/// )
/// ```
///
/// Preset factory constructors are provided for common use-cases:
/// - [DownsampledNetworkImage.avatar] — small circular avatars (≤ 200px)
/// - [DownsampledNetworkImage.thumbnail] — grid/card thumbnails (≤ 400px)
/// - [DownsampledNetworkImage.card] — full-width profile cards (≤ 600px)
/// - [DownsampledNetworkImage.viewer] — full-screen interactive viewer (≤ 1080px)
class DownsampledNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final Widget? placeholderWidget;
  final Widget? errorFallbackWidget;

  const DownsampledNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.errorWidget,
    this.placeholderWidget,
    this.errorFallbackWidget,
  });

  /// For small circular avatars rendered at ≤ 100 logical px diameter.
  const DownsampledNetworkImage.avatar({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.placeholderWidget,
    this.errorFallbackWidget,
  })  : cacheWidth = 200,
        cacheHeight = 200;

  /// For grid/list thumbnails rendered at ≤ 200 logical px.
  const DownsampledNetworkImage.thumbnail({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.placeholderWidget,
    this.errorFallbackWidget,
  })  : cacheWidth = 400,
        cacheHeight = 400;

  /// For card-sized images (profile cards, half-screen or less).
  const DownsampledNetworkImage.card({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.placeholderWidget,
    this.errorFallbackWidget,
  })  : cacheWidth = 600,
        cacheHeight = null;

  /// For full-screen interactive viewers — downsamples to a reasonable upper
  /// bound without losing visible quality on high-DPI displays.
  const DownsampledNetworkImage.viewer({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
    this.placeholderWidget,
    this.errorFallbackWidget,
  })  : cacheWidth = 1080,
        cacheHeight = null;

  @override
  Widget build(BuildContext context) {
    Widget defaultPlaceholder(BuildContext ctx, String url) {
      if (placeholder != null) return placeholder!(ctx, url);
      if (placeholderWidget != null) return placeholderWidget!;
      return Container(
        color: Theme.of(ctx)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    Widget defaultError(BuildContext ctx, String url, Object error) {
      if (errorWidget != null) return errorWidget!(ctx, url, error);
      if (errorFallbackWidget != null) return errorFallbackWidget!;
      return Container(
        color: Theme.of(ctx)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        child: Icon(
          Icons.broken_image_outlined,
          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      placeholder: defaultPlaceholder,
      errorWidget: defaultError,
    );
  }
}
