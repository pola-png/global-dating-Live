import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final ModernButtonStyle style;
  final Color? backgroundColor;
  final Color? foregroundColor;
  
  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.style = ModernButtonStyle.filled,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget button = _buildButton(theme);
    
    if (widget.isExpanded) {
      button = SizedBox(width: double.infinity, child: button);
    }
    
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: button,
      ),
    );
  }

  Widget _buildButton(ThemeData theme) {
    final content = _buildContent();
    
    switch (widget.style) {
      case ModernButtonStyle.filled:
        return FilledButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: widget.backgroundColor,
            foregroundColor: widget.foregroundColor,
          ),
          child: content,
        );
      case ModernButtonStyle.outlined:
        return OutlinedButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.foregroundColor ?? theme.colorScheme.primary,
          ),
          child: content,
        );
      case ModernButtonStyle.text:
        return TextButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: TextButton.styleFrom(
            foregroundColor: widget.foregroundColor ?? theme.colorScheme.primary,
          ),
          child: content,
        );
    }
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    
    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 18),
          const SizedBox(width: 8),
          Text(widget.text),
        ],
      );
    }
    
    return Text(widget.text);
  }
}

enum ModernButtonStyle {
  filled,
  outlined,
  text,
}

class ModernFloatingActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final bool isExtended;
  final String? label;
  
  const ModernFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.isExtended = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (isExtended && label != null) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label!),
        tooltip: tooltip,
      ).animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.3, end: 0);
    }
    
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      child: Icon(icon),
    ).animate()
      .fadeIn(duration: 300.ms)
      .scale(begin: const Offset(0.8, 0.8));
  }
}