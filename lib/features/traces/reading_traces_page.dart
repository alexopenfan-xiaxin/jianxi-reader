import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/bookmark_service.dart';
import '../../core/design_tokens.dart';
import '../../core/file_rules.dart';
import '../../core/reading_history_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page_route.dart';
import '../../data/metadata/metadata_store.dart';
import '../library/document_entry.dart';
import '../reader/reader_page.dart';

enum _TraceTab { bookmarks, history }

/// One place for what the reader left behind: bookmarks, and when each document
/// was last opened.
///
/// 2.x wrote both and never showed either; 3.0 turns the data into the "find it
/// again" half of the product promise.
class ReadingTracesPage extends StatefulWidget {
  const ReadingTracesPage({super.key});

  @override
  State<ReadingTracesPage> createState() => _ReadingTracesPageState();
}

class _ReadingTracesPageState extends State<ReadingTracesPage> {
  _TraceTab _tab = _TraceTab.bookmarks;
  List<ReadingBookmark> _bookmarks = const [];
  List<ReadingHistoryEvent> _history = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final bookmarks = await BookmarkService.loadAll();
      final history = await ReadingHistoryService.recentEvents(limit: 100);
      bookmarks.sort(
        (left, right) => right.createdAtMillis.compareTo(left.createdAtMillis),
      );
      if (!mounted) return;
      setState(() {
        _bookmarks = bookmarks;
        _history = history;
      });
    } catch (error) {
      debugPrint('[ReadingTraces] load failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeBookmark(ReadingBookmark bookmark) async {
    try {
      await BookmarkService.remove(bookmark.id);
      if (!mounted) return;
      setState(() {
        _bookmarks = _bookmarks
            .where((entry) => entry.id != bookmark.id)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除书签')),
      );
    } catch (error) {
      debugPrint('[ReadingTraces] delete failed: $error');
    }
  }

  Future<void> _openTrace(String documentId, double? ratio) async {
    final snapshot = await MetadataStore.load();
    final record = snapshot.recordForId(documentId);
    final path = record?.path;
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这篇文档已不在文档库里')),
      );
      return;
    }

    final type = DocumentFileRules.typeForPath(path);
    DocumentEntry entry;
    if (type == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不支持的文档类型')),
      );
      return;
    }
    if (File(path).existsSync()) {
      entry = await DocumentEntry.fromFile(
        File(path),
        tags: record?.tags ?? const [],
        pinned: record?.pinned ?? false,
      );
    } else {
      entry = DocumentEntry.missing(
        path: path,
        type: type,
        tags: record?.tags ?? const [],
        pinned: record?.pinned ?? false,
      );
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute<void>(
        builder: (context) => ReaderPage(
          document: entry,
          initialProgressRatio: ratio,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.parchment,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '阅读痕迹',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      '完成',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  _TraceTabChip(
                    label: '书签 ${_bookmarks.length}',
                    selected: _tab == _TraceTab.bookmarks,
                    onTap: () => setState(() => _tab = _TraceTab.bookmarks),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _TraceTabChip(
                    label: '历史 ${_history.length}',
                    selected: _tab == _TraceTab.history,
                    onTap: () => setState(() => _tab = _TraceTab.history),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _buildBody(palette)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ReadingPalette palette) {
    if (_isLoading) {
      return Center(
        child: Text(
          '正在整理…',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: palette.muted),
        ),
      );
    }
    if (_tab == _TraceTab.bookmarks) {
      if (_bookmarks.isEmpty) {
        return _traceEmpty(palette, '还没有书签。阅读时点右上角的书签按钮即可添加。');
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        itemCount: _bookmarks.length,
        itemBuilder: (context, index) {
          final bookmark = _bookmarks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              onTap: () =>
                  _openTrace(bookmark.documentId, bookmark.progressRatio),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookmark.title.isEmpty ? '未命名书签' : bookmark.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          _subtitle(
                            '读到 ${(bookmark.progressRatio * 100).toStringAsFixed(0)}%',
                            bookmark.note,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: palette.muted,
                                fontSize: 12,
                                letterSpacing: 0,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '删除书签',
                    visualDensity: VisualDensity.comfortable,
                    onPressed: () => _removeBookmark(bookmark),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (_history.isEmpty) {
      return _traceEmpty(palette, '还没有阅读记录。');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final event = _history[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            onTap: () => _openTrace(event.documentId, event.progressRatio),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                        future: _titleFor(event.documentId),
                        builder: (context, snapshot) => Text(
                          snapshot.data ?? '文档',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _timeLabel(event.openedAtMillis),
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              color: palette.muted,
                              fontSize: 12,
                              letterSpacing: 0,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: palette.muted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _traceEmpty(ReadingPalette palette, String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: palette.muted,
          height: 1.6,
        ),
      ),
    );
  }

  String _subtitle(String head, String? note) {
    if (note == null || note.trim().isEmpty) return head;
    return '$head · ${note.trim()}';
  }

  Future<String> _titleFor(String documentId) async {
    final snapshot = await MetadataStore.load();
    final record = snapshot.recordForId(documentId);
    final path = record?.path;
    if (path == null) return '文档';
    return p.basename(path);
  }

  String _timeLabel(int milliseconds) {
    final time = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return '刚刚阅读';
    if (difference.inHours < 1) return '${difference.inMinutes} 分钟前阅读';
    if (difference.inDays < 1) return '${difference.inHours} 小时前阅读';
    if (difference.inDays < 30) return '${difference.inDays} 天前阅读';
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} 阅读';
  }
}

class _TraceTabChip extends StatelessWidget {
  const _TraceTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : palette.dividerSoft,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: selected ? Colors.white : palette.muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}
