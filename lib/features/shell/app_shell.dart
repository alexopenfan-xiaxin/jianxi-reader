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

class _FloatingBottomNav extends StatelessWidget {
  const _FloatingBottomNav({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1C1C1E) : palette.card)
                    .withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: palette.hairline.withValues(alpha: 0.4),
                ),
              ),
              child: NavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: onChanged,
                height: 60,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                indicatorColor: AppColors.primary.withValues(alpha: 0.12),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: '首页',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: '设置',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
