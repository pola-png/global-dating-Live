import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ModernCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final bool enableHover;
  final bool enablePress;
  
  const ModernCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.enableHover = true,
    this.enablePress = true,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      transform: Matrix4.identity()
        ..scale(_isPressed ? 0.98 : (_isHovered ? 1.02 : 1.0)),
      child: Card(
        elevation: widget.elevation ?? (_isHovered ? 4 : 1),
        color: widget.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: widget.enablePress ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: widget.enablePress ? (_) => setState(() => _isPressed = false) : null,
          onTapCancel: widget.enablePress ? () => setState(() => _isPressed = false) : null,
          onHover: widget.enableHover ? (hovering) => setState(() => _isHovered = hovering) : null,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.all(16),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class ModernProfileCard extends StatelessWidget {
  final String name;
  final int age;
  final String? location;
  final String? imageUrl;
  final List<String> interests;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onPass;
  
  const ModernProfileCard({
    super.key,
    required this.name,
    required this.age,
    this.location,
    this.imageUrl,
    this.interests = const [],
    this.onTap,
    this.onLike,
    this.onPass,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ModernCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
          ),
          
          // Profile Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$name, $age',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (location != null) ...[
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        location!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                
                if (interests.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: interests.take(3).map((interest) => Chip(
                      label: Text(
                        interest,
                        style: theme.textTheme.bodySmall,
                      ),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      side: BorderSide.none,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  ),
                ],
                
                if (onLike != null || onPass != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (onPass != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onPass,
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Pass'),
                          ),
                        ),
                      if (onLike != null && onPass != null) const SizedBox(width: 12),
                      if (onLike != null)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onLike,
                            icon: const Icon(Icons.favorite, size: 18),
                            label: const Text('Like'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 400.ms)
      .slideY(begin: 0.1, end: 0);
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.person,
          size: 64,
          color: Colors.grey,
        ),
      ),
    );
  }
}