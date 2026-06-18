import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings_controller.dart';
import '../../core/design_tokens.dart';
import '../../core/file_rules.dart';
import '../../core/haptic_service.dart';
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

enum _DocumentMenuAction { rename, tags, remove }

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  bool _hasPlayedInitialListAnimation = false;

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
                          118,
                        ),
                        sliver: _LibraryAnimatedContent(
                        controller: controller,
                        viewMode: settings,
                        staggerController: _staggerController,
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
                child: _FixedLibraryHeader(controller: controller),
              ),
              Positioned(
                right: AppSpacing.lg,
                bottom: 86,
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
  ) {
    return _importAndMaybeOpen(context, controller);
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
