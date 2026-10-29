part of 'library_page.dart';

class _LibrarySearchPage extends StatefulWidget {
  const _LibrarySearchPage();

  @override
  State<_LibrarySearchPage> createState() => _LibrarySearchPageState();
}

enum _SearchScope { title, fullText }

class _LibrarySearchPageState extends State<_LibrarySearchPage> {
  late final TextEditingController _controller;
  late final LibraryController _libraryController;
  _SearchScope _scope = _SearchScope.title;
  List<SearchHit> _hits = const [];
  bool _isSearchingText = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _libraryController = context.read<LibraryController>();
    _controller = TextEditingController(text: _libraryController.searchQuery);
    _controller.addListener(_handleQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_handleQueryChanged);
    _libraryController.updateSearchQuery('');
    _libraryController.updateSelectedTag(null);
    _controller.dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _runFullTextSearch);
  }

  void _setScope(_SearchScope scope) {
    if (_scope == scope) return;
    setState(() {
      _scope = scope;
      _hits = const [];
    });
    if (scope == _SearchScope.fullText) {
      _runFullTextSearch();
    }
  }

  Future<void> _runFullTextSearch() async {
    final query = _controller.text.trim();
    if (_scope != _SearchScope.fullText || query.isEmpty) {
      if (mounted && _hits.isNotEmpty) {
        setState(() => _hits = const []);
      }
      return;
    }
    setState(() => _isSearchingText = true);
    try {
      await LibrarySearchIndex.refresh(_libraryController.allDocuments);
      final hits = await LibrarySearchIndex.search(query);
      if (!mounted) return;
      setState(() => _hits = hits);
    } catch (error) {
      debugPrint('[LibrarySearchPage] full-text search failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isSearchingText = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isLiquidGlass = liquidGlassEnabled(context);
    return Scaffold(
      backgroundColor: palette.parchment,
      body: SafeArea(
        child: Consumer<LibraryController>(
          builder: (context, controller, _) {
            final documents = controller.documents;
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Row(
                        children: [
                          Expanded(
                            child: isLiquidGlass
                                ? LiquidGlassTextFieldFrame(
                                    height: 52,
                                    child: _LibrarySearchTextField(
                                      controller: _controller,
                                      libraryController: controller,
                                    ),
                                  )
                                : Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: palette.dividerSoft,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.pill,
                                      ),
                                    ),
                                    child: _LibrarySearchTextField(
                                      controller: _controller,
                                      libraryController: controller,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              '取消',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        '搜索指定标签',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: palette.muted,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SearchTagWrap(controller: controller),
                      const SizedBox(height: AppSpacing.lg),
                      _SearchScopeToggle(scope: _scope, onChanged: _setScope),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        _scope == _SearchScope.fullText
                            ? (_isSearchingText
                                  ? '正在检索正文…'
                                  : '正文命中 ${_hits.length} 处')
                            : '找到 ${documents.length} 个文档',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: palette.muted,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_scope == _SearchScope.fullText
                          ? _hits.isEmpty && !_isSearchingText
                          : documents.isEmpty)
                        _SearchEmptyState(
                          hasQuery: controller.searchQuery.isNotEmpty,
                        ),
                    ]),
                  ),
                ),
                if (_scope == _SearchScope.fullText && _hits.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _FullTextHitTile(
                            hit: _hits[index],
                            query: _controller.text.trim(),
                            documents: controller.allDocuments,
                          ),
                        ),
                        childCount: _hits.length,
                      ),
                    ),
                  ),
                if (_scope == _SearchScope.title && documents.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _SearchResultTile(document: documents[index]),
                        ),
                        childCount: documents.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(
            hasQuery ? Icons.search_off_rounded : Icons.manage_search_rounded,
            color: context.palette.muted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              hasQuery ? '没有找到匹配的文档' : '输入文件名、标签、类型或路径进行搜索',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.palette.muted,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchTagWrap extends StatelessWidget {
  const _SearchTagWrap({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final tags = controller.tags;
    if (tags.isEmpty) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: const [_SearchTagChip(label: '无标签', selected: true)],
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _SearchTagChip(
          key: const ValueKey('search_tag_all'),
          label: '全部',
          selected: controller.selectedTag == null,
          onTap: () => controller.updateSelectedTag(null),
        ),
        for (final tag in tags)
          _SearchTagChip(
            key: ValueKey('search_tag_$tag'),
            label: tag,
            selected: controller.selectedTag == tag,
            onTap: () => controller.updateSelectedTag(tag),
          ),
      ],
    );
  }
}

class _LibrarySearchTextField extends StatefulWidget {
  const _LibrarySearchTextField({
    required this.controller,
    required this.libraryController,
  });

  final TextEditingController controller;
  final LibraryController libraryController;

  @override
  State<_LibrarySearchTextField> createState() =>
      _LibrarySearchTextFieldState();
}

class _LibrarySearchTextFieldState extends State<_LibrarySearchTextField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_commitQuery);
  }

  @override
  void didUpdateWidget(covariant _LibrarySearchTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_commitQuery);
      widget.controller.addListener(_commitQuery);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_commitQuery);
    super.dispose();
  }

  /// CJK input methods hold the pinyin inside the composing region until the
  /// candidate is committed. Filtering on every keystroke turned `jian` into a
  /// "no results" flash that vanished a beat later, so the query only follows
  /// committed text; the commit itself fires a change with no composition.
  void _commitQuery() {
    final value = widget.controller.value;
    if (value.composing.isValid && !value.composing.isCollapsed) {
      return;
    }
    if (value.text == widget.libraryController.searchQuery) {
      return;
    }
    widget.libraryController.updateSearchQuery(value.text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final libraryController = widget.libraryController;
    return Semantics(
      label: '搜索文档',
      textField: true,
      child: TextField(
        key: const ValueKey('library_search_field'),
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '搜索文档',
          prefixIcon: const Icon(Icons.search_rounded),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          suffixIcon: libraryController.searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除搜索',
                  onPressed: () {
                    controller.clear();
                    libraryController.updateSearchQuery('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }
}

class _SearchTagChip extends StatelessWidget {
  const _SearchTagChip({
    required this.label,
    required this.selected,
    this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.primary : context.palette.ink;
    if (liquidGlassEnabled(context)) {
      return LiquidGlassChip(
        label: label,
        selected: selected,
        icon: Icons.label_outline_rounded,
        onTap: onTap,
      );
    }
    return ActionChip(
      onPressed: onTap,
      avatar: const Icon(Icons.label_outline_rounded, size: 18),
      label: Text(label),
      backgroundColor: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : context.palette.dividerSoft,
      labelStyle: TextStyle(
        color: foreground,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        letterSpacing: 0,
      ),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.document});

  final DocumentEntry document;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => _openReader(context, document),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(document.name, style: Theme.of(context).textTheme.titleMedium),
          if (document.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final tag in document.tags.take(3))
                  _SmallTagChip(label: tag),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _documentSummary(document),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.palette.muted,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchScopeToggle extends StatelessWidget {
  const _SearchScopeToggle({required this.scope, required this.onChanged});

  final _SearchScope scope;
  final ValueChanged<_SearchScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SearchScopeChip(
          label: '标题',
          selected: scope == _SearchScope.title,
          onTap: () => onChanged(_SearchScope.title),
        ),
        const SizedBox(width: AppSpacing.sm),
        _SearchScopeChip(
          label: '全文',
          selected: scope == _SearchScope.fullText,
          onTap: () => onChanged(_SearchScope.fullText),
        ),
      ],
    );
  }
}

class _SearchScopeChip extends StatelessWidget {
  const _SearchScopeChip({
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
      label: '搜索范围：$label',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
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

class _FullTextHitTile extends StatelessWidget {
  const _FullTextHitTile({
    required this.hit,
    required this.query,
    required this.documents,
  });

  final SearchHit hit;
  final String query;
  final List<DocumentEntry> documents;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      onTap: () => _openHit(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hit.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            hit.snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.muted,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  void _openHit(BuildContext context) {
    final document = documents.firstWhere(
      (entry) => entry.path == hit.path,
      orElse: () => DocumentEntry(
        path: hit.path,
        name: hit.title,
        type: DocumentFileRules.typeForPath(hit.path) ?? DocumentType.markdown,
        sizeBytes: 0,
        modifiedAt: DateTime.now(),
      ),
    );
    Navigator.of(context).push(
      appPageRoute<void>(
        builder: (context) =>
            ReaderPage(document: document, initialSearchQuery: query),
      ),
    );
  }
}
