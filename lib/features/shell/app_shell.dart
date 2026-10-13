import 'dart:async';
import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings_controller.dart';
import '../../core/design_tokens.dart';
import '../../core/document_error_describer.dart';
import '../../core/haptic_service.dart';
import '../../core/spring_curve.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/liquid_glass.dart';
import '../library/document_entry.dart';
import '../library/library_controller.dart';
import '../library/library_page.dart';
import '../reader/reader_page.dart';
import '../settings/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  int _currentIndex = 0;
  String? _lastExternalUri;
  DateTime? _lastExternalUriAt;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startExternalDocumentListener();
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startExternalDocumentListener() async {
    if (!mounted) return;
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        unawaited(_handleExternalDocumentUri(initialUri));
      }
    } catch (error) {
      debugPrint('[AppShell] read initial external uri failed: $error');
    }

    if (!mounted) return;
    try {
      _linkSubscription ??= _appLinks.uriLinkStream.listen(
        (uri) => unawaited(_handleExternalDocumentUri(uri)),
        onError: (error) {
          debugPrint('[AppShell] external uri stream error: $error');
        },
      );
    } catch (error) {
      debugPrint('[AppShell] subscribe external uri stream failed: $error');
    }
  }

  Future<void> _handleExternalDocumentUri(Uri uri) async {
    if (!mounted || _isDuplicateExternalUri(uri)) {
      return;
    }

    _lastExternalUri = uri.toString();
    _lastExternalUriAt = DateTime.now();

    try {
      final controller = context.read<LibraryController>();
      final document = await controller.importExternalUri(uri);
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      if (_currentIndex != 0) {
        setState(() => _currentIndex = 0);
      }
      unawaited(_openExternalReader(context, document));
    } catch (error) {
      debugPrint('[AppShell] open external document failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开外部文档失败：${describeDocumentError(error)}')),
      );
    }
  }

  bool _isDuplicateExternalUri(Uri uri) {
    final uriValue = uri.toString();
    final lastHandledAt = _lastExternalUriAt;
    if (_lastExternalUri != uriValue || lastHandledAt == null) {
      return false;
    }
    return DateTime.now().difference(lastHandledAt) <
        const Duration(seconds: 2);
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final content = _TabEntrance(
      currentIndex: _currentIndex,
      child: IndexedStack(
        index: _currentIndex,
        children: const [LibraryPage(), SettingsPage()],
      ),
    );
    return Scaffold(
      extendBody: !landscape,
      body: Row(
        children: [
          if (landscape)
            _LandscapeNavigationRail(
              currentIndex: _currentIndex,
              onChanged: (index) => setState(() => _currentIndex = index),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: content),
                if (!landscape)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _FloatingBottomNav(
                      currentIndex: _currentIndex,
                      onChanged: (index) =>
                          setState(() => _currentIndex = index),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Plays a one-shot shared-axis entrance whenever the active tab changes.
///
/// The wrapped [IndexedStack] keeps its identity across switches (it must
/// stay free of a `key`), so both tabs preserve their state; only an
/// entrance animation is layered on top of the newly selected content.
class _TabEntrance extends StatefulWidget {
  const _TabEntrance({required this.currentIndex, required this.child});

  final int currentIndex;
  final Widget child;

  @override
  State<_TabEntrance> createState() => _TabEntranceState();
}

class _TabEntranceState extends State<_TabEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: AppMotion.slow, vsync: this)
      ..forward();
  }

  @override
  void didUpdateWidget(covariant _TabEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SharedAxisTransition(
      animation: _controller,
      secondaryAnimation: kAlwaysDismissedAnimation,
      transitionType: SharedAxisTransitionType.horizontal,
      fillColor: Colors.transparent,
      child: widget.child,
    );
  }
}

class _LandscapeNavigationRail extends StatelessWidget {
  const _LandscapeNavigationRail({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.parchment,
        border: Border(right: BorderSide(color: palette.hairline)),
      ),
      child: NavigationRail(
        minWidth: 72,
        selectedIndex: currentIndex,
        onDestinationSelected: onChanged,
        labelType: NavigationRailLabelType.all,
        backgroundColor: Colors.transparent,
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: Text('文库'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: Text('设置'),
          ),
        ],
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
  static const _itemWidth = 104.0;
  static const _itemHeight = 52.0;
  static const _outerPadding = 4.0;
  static const _navWidth = _itemWidth * 2 + _outerPadding * 2;
  static const _dragThreshold = _itemWidth * 0.35;

  double _dragOffset = 0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final liquidGlass = context.select<AppSettingsController, bool>(
      (settings) => settings.liquidGlassEnabled,
    );
    if (liquidGlass) {
      return _GlassBottomNav(
        currentIndex: widget.currentIndex,
        onChanged: widget.onChanged,
      );
    }

    final selectedLeft =
        _outerPadding +
        widget.currentIndex * _itemWidth +
        _dragOffset.clamp(-_itemWidth, _itemWidth).toDouble();
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
              _isDragging = true;
              final nextOffset = _dragOffset + details.delta.dx;
              _dragOffset = widget.currentIndex == 0
                  ? nextOffset.clamp(0, _itemWidth).toDouble()
                  : nextOffset.clamp(-_itemWidth, 0).toDouble();
            });
          },
          onHorizontalDragEnd: (details) {
            final shouldMoveRight =
                widget.currentIndex == 0 &&
                (_dragOffset > _dragThreshold ||
                    details.primaryVelocity != null &&
                        details.primaryVelocity! > 280);
            final shouldMoveLeft =
                widget.currentIndex == 1 &&
                (_dragOffset < -_dragThreshold ||
                    details.primaryVelocity != null &&
                        details.primaryVelocity! < -280);
            if (shouldMoveRight) {
              _selectIndex(1);
            } else if (shouldMoveLeft) {
              _selectIndex(0);
            }
            setState(() {
              _dragOffset = 0;
              _isDragging = false;
            });
          },
          onHorizontalDragCancel: () {
            setState(() {
              _dragOffset = 0;
              _isDragging = false;
            });
          },
          child: SizedBox(
            width: _navWidth,
            height: _itemHeight,
            child: Stack(
              children: [
                const Positioned.fill(child: _NavGlassBase()),
                AnimatedPositioned(
                  duration: _isDragging ? Duration.zero : AppMotion.normal,
                  curve: SpringCurve.snappy,
                  left: selectedLeft,
                  top: _outerPadding,
                  width: _itemWidth,
                  height: _itemHeight - _outerPadding * 2,
                  child: const _SelectedNavCapsule(),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(_outerPadding),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FloatingNavItem(
                          selected: widget.currentIndex == 0,
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home_rounded,
                          label: '首页',
                          onTap: () {
                            setState(() {
                              _dragOffset = 0;
                              _isDragging = false;
                            });
                            _selectIndex(0);
                          },
                        ),
                        _FloatingNavItem(
                          selected: widget.currentIndex == 1,
                          icon: Icons.settings_outlined,
                          selectedIcon: Icons.settings_rounded,
                          label: '设置',
                          onTap: () {
                            setState(() {
                              _dragOffset = 0;
                              _isDragging = false;
                            });
                            _selectIndex(1);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectIndex(int index) {
    if (index != widget.currentIndex) {
      HapticService.lightImpact();
      widget.onChanged(index);
    }
  }
}

class _GlassBottomNav extends StatelessWidget {
  const _GlassBottomNav({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassIsolationScope(
      isolated: true,
      defaultQuality: GlassQuality.premium,
      child: SafeArea(
        top: false,
        bottom: Theme.of(context).platform == TargetPlatform.android,
        child: GlassTabBar.bottom(
          tabs: const [
            GlassTab(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: '首页',
            ),
            GlassTab(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: '设置',
            ),
          ],
          selectedIndex: currentIndex,
          onTabSelected: (index) {
            if (index == currentIndex) return;
            HapticService.lightImpact();
            onChanged(index);
          },
        ),
      ),
    );
  }
}

Future<void> _openExternalReader(BuildContext context, DocumentEntry document) {
  return Navigator.of(context).push(
    appPageRoute<void>(builder: (context) => ReaderPage(document: document)),
  );
}

class _NavGlassBase extends StatelessWidget {
  const _NavGlassBase();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.card.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: palette.hairline.withValues(alpha: 0.38),
              ),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          splashFactory: NoSplash.splashFactory,
          child: SizedBox(
            height:
                _FloatingBottomNavState._itemHeight -
                _FloatingBottomNavState._outerPadding * 2,
            width: _FloatingBottomNavState._itemWidth,
            child: AnimatedScale(
              scale: selected ? 1.06 : 1,
              duration: AppMotion.settle,
              curve: SpringCurve.bouncy,
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
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0,
                    ),
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
