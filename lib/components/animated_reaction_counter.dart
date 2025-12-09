import 'package:flutter/material.dart';

class AnimatedReactionCounter extends StatefulWidget {
  final int count;
  final int previousCount;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const AnimatedReactionCounter({
    super.key,
    required this.count,
    required this.previousCount,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<AnimatedReactionCounter> createState() => _AnimatedReactionCounterState();
}

class _AnimatedReactionCounterState extends State<AnimatedReactionCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -0.5),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(AnimatedReactionCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count) {
      _controller.forward().then((_) {
        _controller.reset();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.icon,
            color: widget.isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.grey[600],
            size: 20,
          ),
          if (widget.count > 0) ...[
            const SizedBox(width: 4),
            Stack(
              children: [
                // Current count
                Text(
                  widget.count.toString(),
                  style: TextStyle(
                    color: widget.isSelected 
                        ? Theme.of(context).primaryColor 
                        : Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Animated previous count
                if (widget.count != widget.previousCount)
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            widget.previousCount.toString(),
                            style: TextStyle(
                              color: widget.isSelected 
                                  ? Theme.of(context).primaryColor 
                                  : Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}