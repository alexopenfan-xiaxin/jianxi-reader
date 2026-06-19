part of 'library_page.dart';

class _StaggeredFadeIn extends StatelessWidget {
  const _StaggeredFadeIn({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (index >= 12) {
      return child;
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final delay = index * 0.06;
        final t = ((controller.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _LibraryAnimatedContent extends StatelessWidget {
  const _LibraryAnimatedContent({
    required this.controller,
    required this.viewMode,
    required this.staggerController,
    required this.selectedPaths,
    required this.onToggleSelection,
    required this.onStartSelection,
  });

  final LibraryController controller;
  final LibraryViewMode viewMode;
  final AnimationController staggerController;
  final Set<String> selectedPaths;
  final ValueChanged<DocumentEntry> onToggleSelection;
  final ValueChanged<DocumentEntry> onStartSelection;

  @override
  Widget build(BuildContext context) {
    final contentKey = ValueKey(
      '${controller.isLoading}:'
      '${controller.allDocuments.isEmpty}:'
      '${controller.documents.isEmpty}:'
      '${viewMode.name}',
    );

    return _LibrarySliverTransition(
      switchKey: contentKey,
      sliver: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (controller.isLoading) {
      return const SliverToBoxAdapter(
        child: _AnimatedStateShell(child: _LoadingState()),
      );
    }
    if (controller.allDocuments.isEmpty) {
      return const SliverToBoxAdapter(
        child: _AnimatedStateShell(child: _EmptyState()),
      );
    }
    if (controller.documents.isEmpty) {
      return const SliverToBoxAdapter(
        child: _AnimatedStateShell(child: _NoResultsState()),
      );
    }
    if (viewMode == LibraryViewMode.shelf) {
      return SliverMainAxisGroup(
        slivers: [
          if (controller.recentDocuments.isNotEmpty && controller.searchQuery.isEmpty)
            _RecentReadingSliver(documents: controller.recentDocuments),
          _ShelfGrid(
            documents: controller.documents,
            selectedPaths: selectedPaths,
            onToggleSelection: onToggleSelection,
            onStartSelection: onStartSelection,
          ),
        ],
      );
    }
    return SliverMainAxisGroup(
      slivers: [
        if (controller.recentDocuments.isNotEmpty && controller.searchQuery.isEmpty)
          _RecentReadingSliver(documents: controller.recentDocuments),
        _AnimatedDocumentSliverList(
          documents: controller.documents,
          staggerController: staggerController,
          selectedPaths: selectedPaths,
          onToggleSelection: onToggleSelection,
          onStartSelection: onStartSelection,
        ),
      ],
    );
  }
}

class _LibrarySliverTransition extends StatefulWidget {
  const _LibrarySliverTransition({
    required this.switchKey,
    required this.sliver,
  });

  final LocalKey switchKey;
  final Widget sliver;

  @override
  State<_LibrarySliverTransition> createState() =>
      _LibrarySliverTransitionState();
}

class _RecentReadingSliver extends StatelessWidget {
  const _RecentReadingSliver({required this.documents});

  final List<DocumentEntry> documents;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '最近阅读',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${documents.length} 个',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.palette.muted,
                        letterSpacing: 0,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 122,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: documents.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  return _RecentDocumentCard(document: documents[index]);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '全部文档',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentDocumentCard extends StatelessWidget {
  const _RecentDocumentCard({required this.document});

  final DocumentEntry document;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: AppCard(
        onTap: () => _openDocument(context),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  document.type == DocumentType.markdown
                      ? Icons.description_rounded
                      : Icons.code_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                if (document.pinned) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.push_pin_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
            const Spacer(),
            Text(
              document.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xxs),
            FutureBuilder<double?>(
              future: ReadingProgressService.loadProgress(document.path),
              builder: (context, snapshot) {
                final ratio = snapshot.data;
                final progress = ratio == null ? null : (ratio * 100).round();
                return Text(
                  progress == null ? _documentSummary(document) : '读到 $progress%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.palette.muted,
                        fontSize: 12,
                        letterSpacing: 0,
                      ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final controller = context.read<LibraryController>();
    await _openReader(context, document);
    if (context.mounted) {
      await controller.loadDocuments();
    }
  }
}

class _LibrarySliverTransitionState extends State<_LibrarySliverTransition> {
  LocalKey? _lastKey;
  double _opacity = 1;

  @override
  void didUpdateWidget(covariant _LibrarySliverTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.switchKey == widget.switchKey) {
      return;
    }
    _lastKey = widget.switchKey;
    _opacity = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _lastKey == widget.switchKey) {
        setState(() => _opacity = 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SliverAnimatedOpacity(
      key: widget.switchKey,
      opacity: _opacity,
      duration: AppMotion.normal,
      curve: AppMotion.enter,
      sliver: widget.sliver,
    );
  }
}

class _AnimatedDocumentSliverList extends StatefulWidget {
  const _AnimatedDocumentSliverList({
    required this.documents,
    required this.staggerController,
    required this.selectedPaths,
    required this.onToggleSelection,
    required this.onStartSelection,
  });

  final List<DocumentEntry> documents;
  final AnimationController staggerController;
  final Set<String> selectedPaths;
  final ValueChanged<DocumentEntry> onToggleSelection;
  final ValueChanged<DocumentEntry> onStartSelection;

  @override
  State<_AnimatedDocumentSliverList> createState() =>
      _AnimatedDocumentSliverListState();
}

class _AnimatedDocumentSliverListState
    extends State<_AnimatedDocumentSliverList> {
  final _listKey = GlobalKey<SliverAnimatedListState>();
  late List<DocumentEntry> _items;

  @override
  void initState() {
    super.initState();
    _items = List<DocumentEntry>.of(widget.documents);
  }

  @override
  void didUpdateWidget(covariant _AnimatedDocumentSliverList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncItems(widget.documents);
  }

  void _syncItems(List<DocumentEntry> nextDocuments) {
    final nextPaths = nextDocuments.map((document) => document.path).toSet();
    for (var index = _items.length - 1; index >= 0; index--) {
      final document = _items[index];
      if (nextPaths.contains(document.path)) {
        continue;
      }
      _items.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildAnimatedItem(
          document,
          index,
          animation,
          removing: true,
        ),
        duration: const Duration(milliseconds: 200),
      );
    }

    final currentPaths = _items.map((document) => document.path).toSet();
    for (var index = 0; index < nextDocuments.length; index++) {
      final document = nextDocuments[index];
      if (currentPaths.contains(document.path)) {
        continue;
      }
      _items.insert(index, document);
      _listKey.currentState?.insertItem(
        index,
        duration: const Duration(milliseconds: 250),
      );
    }

    setState(() {
      _items = nextDocuments
          .map((next) => _items.firstWhere(
                (item) => item.path == next.path,
                orElse: () => next,
              ).copyWith(
                name: next.name,
                type: next.type,
                sizeBytes: next.sizeBytes,
                modifiedAt: next.modifiedAt,
                recentOpenedAt: next.recentOpenedAt,
                isReferenced: next.isReferenced,
                tags: next.tags,
                pinned: next.pinned,
              ))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SliverAnimatedList(
      key: _listKey,
      initialItemCount: _items.length,
      itemBuilder: (context, index, animation) {
        return _buildAnimatedItem(_items[index], index, animation);
      },
    );
  }

  Widget _buildAnimatedItem(
    DocumentEntry document,
    int index,
    Animation<double> animation, {
    bool removing = false,
  }) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: removing ? AppMotion.exit : AppMotion.enter,
    );
    final tile = Padding(
      key: ValueKey('doc_tile_${document.path}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: _DocumentTile(
        document: document,
        selected: widget.selectedPaths.contains(document.path),
        selectionActive: widget.selectedPaths.isNotEmpty,
        onToggleSelection: widget.onToggleSelection,
        onStartSelection: widget.onStartSelection,
      ),
    );

    return _StaggeredFadeIn(
      index: index,
      controller: widget.staggerController,
      child: FadeTransition(
        opacity: curve,
        child: SizeTransition(
          sizeFactor: curve,
          axisAlignment: -1,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: removing ? Offset.zero : const Offset(0, -0.04),
              end: Offset.zero,
            ).animate(curve),
            child: tile,
          ),
        ),
      ),
    );
  }
}


class _DocumentTile extends StatefulWidget {
  const _DocumentTile({
    required this.document,
    required this.selected,
    required this.selectionActive,
    required this.onToggleSelection,
    required this.onStartSelection,
  });

  final DocumentEntry document;
  final bool selected;
  final bool selectionActive;
  final ValueChanged<DocumentEntry> onToggleSelection;
  final ValueChanged<DocumentEntry> onStartSelection;

  @override
  State<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<_DocumentTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnim;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _hoverAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _hoverController, curve: AppMotion.emphasized),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final liquidGlass = context.select<AppSettingsController, bool>(
      (s) => s.liquidGlassEnabled,
    );
    final forceClassicCard = liquidGlass &&
        Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: widget.document.name,
      hint: widget.selectionActive ? '双击切换选择' : '双击打开阅读，长按多选',
      button: true,
      selected: widget.selected,
      child: AnimatedBuilder(
        animation: _hoverAnim,
        builder: (context, child) => Transform.scale(
          scale: _hoverAnim.value,
          child: child,
        ),
        child: AppCard(
          onTap: widget.selectionActive
              ? () => widget.onToggleSelection(widget.document)
              : () => _openDocument(context),
          onLongPress: () {
            if (widget.selectionActive) {
              widget.onToggleSelection(widget.document);
            } else {
              widget.onStartSelection(widget.document);
            }
          },
          padding: const EdgeInsets.all(AppSpacing.md),
          forceClassic: forceClassicCard,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: 'doc_badge_${widget.document.path}',
                          child: _TypeBadge(document: widget.document),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (widget.document.isReferenced)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: AppSpacing.xxs,
                                      ),
                                      child: Icon(
                                        Icons.link_rounded,
                                        size: 14,
                                        color: palette.muted,
                                      ),
                                    ),
                                  if (widget.document.pinned)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: AppSpacing.xxs,
                                      ),
                                      child: Icon(
                                        Icons.push_pin_rounded,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  Flexible(
                                    child: Text(
                                      widget.document.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                              _DocumentMetaRow(
                                tags: widget.document.tags,
                                summary: _documentSummary(widget.document),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.selectionActive) ...[
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      tooltip: '文档操作',
                      onPressed: () async {
                        final action = await _showGlassDocumentMenu(
                          context,
                          widget.document,
                        );
                        if (action != null && context.mounted) {
                          await _handleAction(context, action);
                        }
                      },
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ],
                ],
              ),
              if (widget.selectionActive)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(
                    widget.selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: widget.selected ? AppColors.primary : palette.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDocument(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final controller = context.read<LibraryController>();
    await _openReader(context, widget.document);
    if (context.mounted) {
      await controller.loadDocuments();
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    _DocumentMenuAction action,
  ) async {
    switch (action) {
      case _DocumentMenuAction.pin:
        final controller = context.read<LibraryController>();
        await controller.setPinned(widget.document, !widget.document.pinned);
      case _DocumentMenuAction.rename:
        await showRenameDocumentDialog(context, widget.document);
      case _DocumentMenuAction.tags:
        await _showTagEditor(context, widget.document);
      case _DocumentMenuAction.remove:
        await removeDocumentFromLibrary(context, widget.document);
    }
  }
}

Future<_DocumentMenuAction?> _showGlassDocumentMenu(
  BuildContext context,
  DocumentEntry document,
) {
  return showModalBottomSheet<_DocumentMenuAction>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.14),
    builder: (context) {
      return LiquidGlassSheetPanel(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(
                document.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _GlassMenuTile(
              icon: document.pinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              title: document.pinned ? '取消置顶' : '置顶',
              action: _DocumentMenuAction.pin,
            ),
            _GlassMenuTile(
              icon: Icons.drive_file_rename_outline_rounded,
              title: '重命名',
              action: _DocumentMenuAction.rename,
            ),
            _GlassMenuTile(
              icon: Icons.label_outline_rounded,
              title: '设置标签',
              action: _DocumentMenuAction.tags,
            ),
            _GlassMenuTile(
              icon: Icons.remove_circle_outline_rounded,
              title: '移出',
              action: _DocumentMenuAction.remove,
              destructive: true,
            ),
          ],
        ),
      );
    },
  );
}

class _GlassMenuTile extends StatelessWidget {
  const _GlassMenuTile({
    required this.icon,
    required this.title,
    required this.action,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final _DocumentMenuAction action;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : context.palette.ink;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              letterSpacing: 0,
            ),
      ),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}

Future<void> _showTagEditor(
  BuildContext context,
  DocumentEntry document, {
  List<DocumentEntry>? documents,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _TagEditorSheet(
      document: document,
      documents: documents ?? [document],
    ),
  );
}

class _TagEditorSheet extends StatefulWidget {
  const _TagEditorSheet({required this.document, required this.documents});

  final DocumentEntry document;
  final List<DocumentEntry> documents;

  @override
  State<_TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<_TagEditorSheet> {
  late final TextEditingController _tagController;
  late final Set<String> _selectedTags;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tagController = TextEditingController();
    _selectedTags = widget.documents.length == 1
        ? widget.document.tags.toSet()
        : <String>{};
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryController>(
      builder: (context, controller, _) {
        final isLiquidGlass = liquidGlassEnabled(context);
        final tagField = TextField(
          key: const ValueKey('tag_name_field'),
          controller: _tagController,
          decoration: InputDecoration(
            hintText: '新建标签',
            border: isLiquidGlass ? InputBorder.none : null,
            enabledBorder: isLiquidGlass ? InputBorder.none : null,
            focusedBorder: isLiquidGlass ? InputBorder.none : null,
            filled: isLiquidGlass ? false : null,
            isDense: isLiquidGlass,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _createTag(controller),
        );
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.documents.length == 1 ? '设置标签' : '批量设置标签',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.documents.length == 1
                  ? widget.document.name
                  : '已选择 ${widget.documents.length} 个文档，勾选后将追加标签',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.palette.muted,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final tag in controller.tags)
                  _EditableTagChip(
                    tag: tag,
                    selected: _selectedTags.contains(tag),
                    pinned: controller.pinnedTags.contains(tag),
                    canDelete: true,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                    onPinnedChanged: (pinned) =>
                        controller.setTagPinned(tag, pinned),
                    onDeleted: () => _deleteTag(controller, tag),
                  ),
                if (controller.tags.isEmpty)
                  Text(
                    '默认无标签。先创建标签，再为文档勾选。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.palette.muted,
                          letterSpacing: 0,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: isLiquidGlass
                      ? LiquidGlassTextFieldFrame(child: tagField)
                      : tagField,
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () => _createTag(controller),
                  child: const Text('添加'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : () => _saveTags(controller),
                    child: Text(_isSaving ? '保存中' : '保存'),
                  ),
                ),
              ],
            ),
          ],
        );

        if (isLiquidGlass) {
          return LiquidGlassSheetPanel(
            margin: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
            ),
            child: content,
          );
        }

        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.palette.card.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createTag(LibraryController controller) async {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) {
      return;
    }
    try {
      await controller.createTag(tag);
      setState(() {
        _selectedTags.add(tag);
        _tagController.clear();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建标签失败：$error')),
        );
      }
    }
  }

  Future<void> _deleteTag(LibraryController controller, String tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => LiquidGlassDialog(
        title: const Text('删除标签'),
        content: Text('删除「$tag」后，所有文档都会移除这个标签。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await controller.deleteTag(tag);
      setState(() => _selectedTags.remove(tag));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除标签失败：$error')),
        );
      }
    }
  }

  Future<void> _saveTags(LibraryController controller) async {
    setState(() => _isSaving = true);
    try {
      if (widget.documents.length > 1) {
        await controller.addDocumentsTags(
          widget.documents,
          _selectedTags.toList(),
        );
      } else {
        await controller.updateDocumentTags(
          widget.document,
          _selectedTags.toList(),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存标签失败：$error')),
        );
      }
    }
  }

}

class _EditableTagChip extends StatelessWidget {
  const _EditableTagChip({
    required this.tag,
    required this.selected,
    required this.pinned,
    required this.canDelete,
    required this.onSelected,
    required this.onPinnedChanged,
    required this.onDeleted,
  });

  final String tag;
  final bool selected;
  final bool pinned;
  final bool canDelete;
  final ValueChanged<bool> onSelected;
  final ValueChanged<bool> onPinnedChanged;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final color = _tagColor(tag);
    if (liquidGlassEnabled(context)) {
      return GestureDetector(
        onLongPress: () => onPinnedChanged(!pinned),
        child: LiquidGlassChip(
          label: tag,
          selected: selected,
          icon: pinned ? Icons.push_pin_rounded : Icons.label_outline_rounded,
          onTap: () => onSelected(!selected),
          onDeleted: canDelete ? onDeleted : null,
        ),
      );
    }
    return InputChip(
      label: Text(tag),
      selected: selected,
      avatar: GestureDetector(
        onTap: () => onPinnedChanged(!pinned),
        child: Icon(
          pinned ? Icons.push_pin_rounded : Icons.label_outline_rounded,
          size: 18,
          color: selected ? Colors.white : color,
        ),
      ),
      onSelected: onSelected,
      onDeleted: canDelete ? onDeleted : null,
      selectedColor: color,
      backgroundColor: color.withOpacity(0.12),
      labelStyle: TextStyle(
        color: selected ? Colors.white : color,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _DocumentMetaRow extends StatelessWidget {
  const _DocumentMetaRow({required this.tags, required this.summary});

  final List<String> tags;
  final String summary;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(
          summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
                fontSize: 12,
                letterSpacing: 0,
              ),
        ),
      );
    }
    final visibleTags = tags.take(2).toList();
    final overflow = tags.length - visibleTags.length;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Flexible(
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final tag in visibleTags) _SmallTagChip(label: tag),
                if (overflow > 0) _SmallTagChip(label: '+$overflow'),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.palette.muted,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallTagChip extends StatelessWidget {
  const _SmallTagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _tagColor(label);
    if (liquidGlassEnabled(context)) {
      return LiquidGlassChip(label: label, selected: true);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
      ),
    );
  }
}

Color _tagColor(String tag) {
  const colors = <Color>[
    Color(0xFF2F6BFF),
    Color(0xFF0F8B6B),
    Color(0xFF9A5A00),
    Color(0xFFC2415B),
    Color(0xFF6D5BD0),
    Color(0xFF087EA4),
  ];
  final hash = tag.codeUnits.fold<int>(
    0,
    (value, unit) => (value * 31 + unit) & 0x7fffffff,
  );
  return colors[hash % colors.length];
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.document});

  final DocumentEntry document;

  @override
  Widget build(BuildContext context) {
    final isMd = document.type == DocumentType.markdown;
    final badgeColor = isMd ? AppColors.primary : AppColors.htmlBadge;
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: badgeColor.withOpacity(0.18),
        ),
      ),
      child: Icon(
        isMd ? Icons.description_rounded : Icons.code_rounded,
        color: badgeColor,
        size: 20,
      ),
    );
  }
}
