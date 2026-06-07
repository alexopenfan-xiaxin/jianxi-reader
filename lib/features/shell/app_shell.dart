import 'dart:async';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../core/haptic_service.dart';
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
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        unawaited(_handleExternalDocumentUri(initialUri));
      }
    } catch (error) {
      debugPrint('[AppShell] read initial external uri failed: $error');
    }

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
        SnackBar(content: Text('打开外部文档失败：$error')),
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
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: AppMotion.slow,
              switchInCurve: AppMotion.emphasized,
              switchOutCurve: AppMotion.exit,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: AppMotion.emphasized,
                  ),
                  child: child,
                );
              },
              child: IndexedStack(
                index: _currentIndex,
                children: const [LibraryPage(), SettingsPage()],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FloatingBottomNav(
              currentIndex: _currentIndex,
              onChanged: (index) => setState(() => _currentIndex = index),
            ),
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
    final selectedLeft = _outerPadding +
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
                  duration: _isDragging
                      ? Duration.zero
                      : AppMotion.normal,
                  curve: AppMotion.emphasized,
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
      HapticService.selectionClick();
      widget.onChanged(index);
    }
  }
}

Future<void> _openExternalReader(BuildContext context, DocumentEntry document) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          ReaderPage(document: document),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: AppMotion.emphasized,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(curve),
          child: FadeTransition(opacity: curve, child: child),
        );
      },
      transitionDuration: AppMotion.slow,
    ),
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
            height: _FloatingBottomNavState._itemHeight -
                _FloatingBottomNavState._outerPadding * 2,
            width: _FloatingBottomNavState._itemWidth,
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
    );
  }
}
