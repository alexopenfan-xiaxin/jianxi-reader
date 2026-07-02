import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings_controller.dart';
import '../../core/design_tokens.dart';
import '../../core/file_rules.dart';
import '../../core/haptic_service.dart';
import '../../core/reading_progress_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/liquid_glass.dart';
import '../reader/reader_page.dart';
import 'document_actions.dart';
import 'document_entry.dart';
import 'library_controller.dart';

part 'library_empty_state.dart';
part 'library_list_view.dart';
part 'library_search_page.dart';
part 'library_shelf_view.dart';
part 'library_toolbar.dart';

enum _DocumentMenuAction { pin, rename, tags, remove }
enum _ImportAction { files, folder }

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  bool _hasPlayedInitialListAnimation = false;
  final Set<String> _selectedPaths = {};

  bool get _selectionActive => _selectedPaths.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      duration: AppMotion.slow,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return SafeArea(
      child: Consumer<LibraryController>(
        builder: (context, controller, _) {
          final settings = context.select<AppSettingsController, LibraryViewMode>(
            (s) => s.libraryViewMode,
          );
          if (!_hasPlayedInitialListAnimation &&
              controller.documents.isNotEmpty) {
            _hasPlayedInitialListAnimation = true;
            _staggerController.reset();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _staggerController.forward();
              }
            });
          }
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: CustomScrollView(
                    slivers: [
                      if (controller.errorMessage != null)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            82,
                            AppSpacing.lg,
                            0,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _ErrorBanner(
                              message: controller.errorMessage!,
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          controller.errorMessage == null ? 82 : AppSpacing.md,
                          AppSpacing.lg,
                          landscape ? AppSpacing.lg : 118,
                        ),
                        sliver: _LibraryAnimatedContent(
                          controller: controller,
                          viewMode: settings,
                          staggerController: _staggerController,
                          selectedPaths: _selectedPaths,
                          onToggleSelection: _toggleSelection,
                          onStartSelection: _startSelection,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _selectionActive
                    ? _SelectionHeader(
                        selectedCount: _selectedPaths.length,
                        onClose: _clearSelection,
                        onTags: () => _showBatchTagEditor(context, controller),
                        onRefresh: () => _runBatchRefresh(context, controller),
                        onClearProgress: () =>
                            _confirmClearProgress(context, controller),
                        onRemove: () => _confirmBatchRemove(context, controller),
                      )
                    : _FixedLibraryHeader(controller: controller),
              ),
              if (!_selectionActive)
                Positioned(
                  right: AppSpacing.lg,
                  bottom: landscape ? AppSpacing.lg : 86,
                  child: _FloatingImportButton(
                    key: const ValueKey('import_button'),
                    importing: controller.isImporting,
                    onPressed: () => _importDocuments(context, controller),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _importDocuments(
    BuildContext context,
    LibraryController controller,
  ) async {
    final action = await _showImportSheet(context);
    if (!context.mounted || action == null) {
      return;
    }
    switch (action) {
      case _ImportAction.files:
        await _importAndMaybeOpen(context, controller);
        return;
      case _ImportAction.folder:
        await _importFolderAndShowResult(context, controller);
        return;
    }
  }

  void _startSelection(DocumentEntry document) {
    HapticService.mediumImpact();
    setState(() => _selectedPaths.add(document.path));
  }

  void _toggleSelection(DocumentEntry document) {
    setState(() {
      if (!_selectedPaths.remove(document.path)) {
        _selectedPaths.add(document.path);
      }
    });
  }

  void _clearSelection() {
    setState(_selectedPaths.clear);
  }

  List<DocumentEntry> _selectedDocuments(LibraryController controller) {
    return controller.allDocuments
        .where((document) => _selectedPaths.contains(document.path))
        .toList();
  }

  Future<void> _showBatchTagEditor(
    BuildContext context,
    LibraryController controller,
  ) async {
    final selected = _selectedDocuments(controller);
    if (selected.isEmpty) {
      return;
    }
    await _showTagEditor(context, selected.first, documents: selected);
    if (mounted) {
      _clearSelection();
    }
  }

  Future<void> _runBatchRefresh(
    BuildContext context,
    LibraryController controller,
  ) async {
    final selected = _selectedDocuments(controller);
    final result = await controller.refreshDocuments(selected);
    if (!context.mounted) {
      return;
    }
    _clearSelection();
    _showBatchResult(context, result, '已刷新 ${result.success} 个文档');
  }

  Future<void> _confirmClearProgress(
    BuildContext context,
    LibraryController controller,
  ) async {
    final confirmed = await _confirmBatchAction(
      context,
      title: '清除阅读进度',
      content: '将清除已选择文档的阅读进度，不会删除文档。',
      confirmText: '清除',
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final result = await controller.clearDocumentsProgress(
      _selectedDocuments(controller),
    );
    if (!context.mounted) {
      return;
    }
    _clearSelection();
    _showBatchResult(context, result, '已清除 ${result.success} 个文档的阅读进度');
  }

  Future<void> _confirmBatchRemove(
    BuildContext context,
    LibraryController controller,
  ) async {
    final confirmed = await _confirmBatchAction(
      context,
      title: '移出文档',
      content: '将移出已选择的 ${_selectedPaths.length} 个文档。',
      confirmText: '移出',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final result = await controller.removeDocuments(_selectedDocuments(controller));
    if (!context.mounted) {
      return;
    }
    _clearSelection();
    _showBatchResult(context, result, '已移出 ${result.success} 个文档');
  }
}

Future<bool?> _confirmBatchAction(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmText,
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => LiquidGlassDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.error)
              : null,
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

void _showBatchResult(
  BuildContext context,
  LibraryBatchResult result,
  String successMessage,
) {
  final message = result.hasFailure
      ? '$successMessage，${result.failure} 个失败'
      : successMessage;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<_ImportAction?> _showImportSheet(BuildContext context) {
  return showModalBottomSheet<_ImportAction>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.14),
    builder: (context) {
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '添加到书库',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
              ),
            ),
          ),
          _ImportOptionTile(
            icon: Icons.description_outlined,
            title: '导入文件',
            subtitle: '选择一个或多个 Markdown / HTML 文件',
            action: _ImportAction.files,
          ),
          _ImportOptionTile(
            icon: Icons.folder_open_rounded,
            title: '导入文件夹',
            subtitle: '自动添加文件夹内支持的文档',
            action: _ImportAction.folder,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      );

      if (liquidGlassEnabled(context)) {
        return LiquidGlassSheetPanel(padding: EdgeInsets.zero, child: content);
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: SafeArea(top: false, child: content),
        ),
      );
    },
  );
}

class _ImportOptionTile extends StatelessWidget {
  const _ImportOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _ImportAction action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.muted,
              letterSpacing: 0,
            ),
      ),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}

Future<void> _importAndMaybeOpen(
  BuildContext context,
  LibraryController controller,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final documents = await controller.importExternalDocuments();
  if (!context.mounted || documents.isEmpty) {
    return;
  }
  HapticService.lightImpact();
  if (documents.length > 1) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导入 ${documents.length} 个文档')),
    );
    return;
  }
  await _openReader(context, documents.single);
  if (context.mounted) {
    await controller.loadDocuments();
  }
}

Future<void> _importFolderAndShowResult(
  BuildContext context,
  LibraryController controller,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final result = await controller.importExternalFolderDocuments();
  if (!context.mounted || result.documents.isEmpty) {
    return;
  }
  HapticService.lightImpact();
  final suffix = [
    if (result.skipped > 0) '跳过 ${result.skipped} 个',
    if (result.failed > 0) '失败 ${result.failed} 个',
  ].join('，');
  final message = suffix.isEmpty
      ? '已导入 ${result.documents.length} 个文档'
      : '已导入 ${result.documents.length} 个文档，$suffix';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
  if (result.documents.length == 1) {
    await _openReader(context, result.documents.single);
    if (context.mounted) {
      await controller.loadDocuments();
    }
  }
}

Future<void> _openReader(BuildContext context, DocumentEntry document) {
  return Navigator.of(context).push(
    appPageRoute<void>(builder: (context) => ReaderPage(document: document)),
  );
}

String _documentSummary(DocumentEntry document) {
  final timePrefix = document.recentOpenedAt == null ? '修改' : '最近阅读';
  final time = document.recentOpenedAt ?? document.modifiedAt;
  return '$timePrefix ${_timeLabel(time)}';
}

String _timeLabel(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);
  if (difference.inMinutes < 1) {
    return '刚刚';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes} 分钟前';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours} 小时前';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays} 天前';
  }
  return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
}
