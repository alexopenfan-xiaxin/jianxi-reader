import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import 'toc_service.dart';

class TocDrawer extends StatefulWidget {
  const TocDrawer({
    required this.entries,
    required this.onSelected,
    required this.documentName,
    required this.progressRatio,
    required this.onBackToTop,
    super.key,
  });

  final List<TocEntry> entries;
  final ValueChanged<TocEntry> onSelected;
  final String documentName;
  final double progressRatio;
  final VoidCallback onBackToTop;

  @override
  State<TocDrawer> createState() => _TocDrawerState();
}

class _TocDrawerState extends State<TocDrawer> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveEntry(animated: false);
    });
  }

  @override
  void didUpdateWidget(covariant TocDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progressRatio != widget.progressRatio) {
      _scrollToActiveEntry(animated: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int get _activeIndex {
    if (widget.entries.isEmpty) return 0;
    return (widget.progressRatio * widget.entries.length).floor().clamp(
      0,
      widget.entries.length - 1,
    );
  }

  void _scrollToActiveEntry({bool animated = false}) {
    if (!_scrollController.hasClients || widget.entries.isEmpty) return;

    // Estimate each ListTile height: dense ListTile ≈ 48px vertical.
    const itemHeight = 48.0;
    final activeIndex = _activeIndex;
    // Center the active item in the visible viewport when possible.
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = (activeIndex * itemHeight) - (viewportHeight * 0.35);
    final maxScroll = _scrollController.position.maxScrollExtent;
    final clamped = targetOffset.clamp(0.0, maxScroll);

    if (animated) {
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Drawer(
      backgroundColor: palette.parchment,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.documentName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '阅读进度 ${(widget.progressRatio * 100).round()}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.muted,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: OutlinedButton.icon(
                onPressed: widget.onBackToTop,
                icon: const Icon(Icons.vertical_align_top_rounded),
                label: const Text('返回顶部'),
              ),
            ),
            Divider(color: palette.hairline),
            Expanded(
              child: widget.entries.isEmpty
                  ? Center(
                      child: Text(
                        '当前文档没有目录',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.muted,
                          letterSpacing: 0,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      itemCount: widget.entries.length,
                      itemBuilder: (context, index) {
                        final entry = widget.entries[index];
                        return _TocTile(
                          entry: entry,
                          active: index == _activeIndex,
                          onTap: () => widget.onSelected(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TocTile extends StatelessWidget {
  const _TocTile({
    required this.entry,
    required this.active,
    required this.onTap,
  });

  final TocEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final indent = (entry.level - 1) * 16.0;
    return ListTile(
      dense: true,
      selected: active,
      selectedTileColor: AppColors.primary.withOpacity(0.10),
      contentPadding: EdgeInsets.fromLTRB(
        AppSpacing.lg + indent,
        0,
        AppSpacing.lg,
        0,
      ),
      title: Text(
        entry.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: entry.level == 1 ? palette.ink : palette.muted,
          fontWeight: active || entry.level == 1
              ? FontWeight.w700
              : FontWeight.w500,
          letterSpacing: 0,
        ),
      ),
      onTap: onTap,
    );
  }
}
