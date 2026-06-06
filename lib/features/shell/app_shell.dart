import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import '../library/library_page.dart';
import '../settings/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
        child: IndexedStack(
          index: _currentIndex,
          children: const [LibraryPage(), SettingsPage()],
        ),
      ),
      bottomNavigationBar: _FloatingBottomNav(
        currentIndex: _currentIndex,
        onChanged: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _FloatingBottomNav extends StatefulWidget {
  const _FloatingBottomNav({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  State<_FloatingBottomNav> createState() => _FloatingBottomNavState();
}

class _FloatingBottomNavState extends State<_FloatingBottomNav> {
  static const _itemWidth = 100.0;
  static const _itemHeight = 52.0;
  static const _gap = 8.0;

  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragOffset = (_dragOffset + details.delta.dx).clamp(
                -_itemWidth - _gap,
                _itemWidth + _gap,
              );
            });
          },
          onHorizontalDragEnd: (details) {
            final shouldMoveRight =
                widget.currentIndex == 0 &&
                    (_dragOffset > 38 ||
                        details.primaryVelocity != null &&
                            details.primaryVelocity! > 280);
            final shouldMoveLeft =
                widget.currentIndex == 1 &&
                    (_dragOffset < -38 ||
                        details.primaryVelocity != null &&
                            details.primaryVelocity! < -280);
            if (shouldMoveRight) {
              widget.onChanged(1);
            } else if (shouldMoveLeft) {
              widget.onChanged(0);
            }
            setState(() => _dragOffset = 0);
          },
          onHorizontalDragCancel: () => setState(() => _dragOffset = 0),
          child: SizedBox(
            width: _itemWidth * 2 + _gap,
            height: _itemHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: (widget.currentIndex == 0 ? 0 : _itemWidth + _gap) +
                      _dragOffset,
                  top: 0,
                  width: _itemWidth,
                  height: _itemHeight,
                  child: const _SelectedNavCapsule(),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FloatingNavItem(
                      selected: widget.currentIndex == 0,
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: '首页',
                      onTap: () {
                        setState(() => _dragOffset = 0);
                        widget.onChanged(0);
                      },
                    ),
                    const SizedBox(width: _gap),
                    _FloatingNavItem(
                      selected: widget.currentIndex == 1,
                      icon: Icons.settings_outlined,
                      selectedIcon: Icons.settings_rounded,
                      label: '设置',
                      onTap: () {
                        setState(() => _dragOffset = 0);
                        widget.onChanged(1);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedNavCapsule extends StatelessWidget {
  const _SelectedNavCapsule();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  const _FloatingNavItem({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = selected ? AppColors.primary : palette.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              splashFactory: NoSplash.splashFactory,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: _FloatingBottomNavState._itemHeight,
                width: _FloatingBottomNavState._itemWidth,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.card.withValues(alpha: selected ? 0.18 : 0.58),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                    color: palette.hairline.withValues(alpha: 0.32),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? selectedIcon : icon,
                      color: foreground,
                      size: 21,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: foreground,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            letterSpacing: 0,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
