import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ModernBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final List<ModernBottomNavItem> items;
  
  const ModernBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == currentIndex;
              
              return Expanded(
                child: _ModernBottomNavButton(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onTap(index),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _ModernBottomNavButton extends StatelessWidget {
  final ModernBottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _ModernBottomNavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? theme.colorScheme.primaryContainer 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                color: isSelected 
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ).animate(target: isSelected ? 1 : 0)
              .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
            
            const SizedBox(height: 4),
            
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: theme.textTheme.labelSmall!.copyWith(
                color: isSelected 
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

class ModernBottomNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badgeCount;
  
  const ModernBottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
  });
}

class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  
  const ModernAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle = true,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: titleWidget ?? (title != null ? Text(title!) : null),
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      centerTitle: centerTitle,
      bottom: bottom,
    ).animate()
      .fadeIn(duration: 300.ms)
      .slideY(begin: -0.2, end: 0);
  }

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0),
  );
}

class ModernTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Tab> tabs;
  final TabController? controller;
  final void Function(int)? onTap;
  final bool isScrollable;
  
  const ModernTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.onTap,
    this.isScrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        tabs: tabs,
        controller: controller,
        onTap: onTap,
        isScrollable: isScrollable,
        indicatorColor: theme.colorScheme.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w400,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);
}