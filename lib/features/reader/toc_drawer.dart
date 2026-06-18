import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import 'toc_service.dart';

class TocDrawer extends StatelessWidget {
  const TocDrawer({
    required this.entries,
    required this.onSelected,
    super.key,
  });

  final List<TocEntry> entries;
  final ValueChanged<TocEntry> onSelected;

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
              child: Text(
                '文档目录',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
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
}

class _TocTile extends StatelessWidget {
  const _TocTile({
    required this.entry,
    required this.onTap,
  });

  final TocEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final indent = (entry.level - 1) * 16.0;
    return ListTile(
      dense: true,
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
              fontWeight: entry.level == 1 ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0,
            ),
      ),
      onTap: onTap,
    );
  }
}
