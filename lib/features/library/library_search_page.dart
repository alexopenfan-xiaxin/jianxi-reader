part of 'library_page.dart';

class _LibrarySearchPage extends StatefulWidget {
  const _LibrarySearchPage();

  @override
  State<_LibrarySearchPage> createState() => _LibrarySearchPageState();
}

class _LibrarySearchPageState extends State<_LibrarySearchPage> {
  late final TextEditingController _controller;
  late final LibraryController _libraryController;

  @override
  void initState() {
    super.initState();
    _libraryController = context.read<LibraryController>();
    _controller = TextEditingController(text: _libraryController.searchQuery);
  }

  @override
  void dispose() {
    _libraryController.updateSearchQuery('');
    _libraryController.updateSelectedTag(null);
    _controller.dispose();
    super.dispose();
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
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
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
                                borderRadius:
                                    BorderRadius.circular(AppRadii.pill),
                              ),
                              child: _LibrarySearchTextField(
                                controller: _controller,
                                libraryController: controller,
                              ),
                            ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
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
                const SizedBox(height: AppSpacing.xl),
                Text(
                  '找到 ${controller.documents.length} 个文档',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: palette.muted,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (controller.documents.isEmpty)
                  _SearchEmptyState(hasQuery: controller.searchQuery.isNotEmpty)
                else
                  ...controller.documents.map(
                    (document) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _SearchResultTile(document: document),
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
          label: '全部',
          selected: controller.selectedTag == null,
          onTap: () => controller.updateSelectedTag(null),
        ),
        for (final tag in tags)
          _SearchTagChip(
            label: tag,
            selected: controller.selectedTag == tag,
            onTap: () => controller.updateSelectedTag(tag),
          ),
      ],
    );
  }
}

class _LibrarySearchTextField extends StatelessWidget {
  const _LibrarySearchTextField({
    required this.controller,
    required this.libraryController,
  });

  final TextEditingController controller;
  final LibraryController libraryController;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '搜索文档',
      textField: true,
      child: TextField(
        key: const ValueKey('library_search_field'),
        controller: controller,
        autofocus: true,
        onChanged: libraryController.updateSearchQuery,
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
          ? AppColors.primary.withOpacity(0.12)
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
