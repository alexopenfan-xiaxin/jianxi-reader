import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import 'toc_service.dart';

class TocDrawer extends StatelessWidget {
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
                    documentName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '阅读进度 ${(progressRatio * 100).round()}%',
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
                onPressed: onBackToTop,
                icon: const Icon(Icons.vertical_align_top_rounded),
                label: const Text('返回顶部'),
              ),
            ),
            Divider(color: palette.hairline),
            Expanded(
              child: entries.isEmpty
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
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _TocTile(
                          entry: entry,
                          active: _isActiveEntry(index),
                          onTap: () => onSelected(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isActiveEntry(int index) {
    if (entries.isEmpty) {
      return false;
    }
    final activeIndex = (progressRatio * entries.length)
        .floor()
        .clamp(0, entries.length - 1);
    return index == activeIndex;
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
