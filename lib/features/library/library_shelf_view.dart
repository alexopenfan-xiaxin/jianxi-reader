part of 'library_page.dart';

class _ShelfGrid extends StatelessWidget {
  const _ShelfGrid({
    required this.documents,
    required this.selectedPaths,
    required this.onToggleSelection,
    required this.onStartSelection,
  });

  final List<DocumentEntry> documents;
  final Set<String> selectedPaths;
  final ValueChanged<DocumentEntry> onToggleSelection;
  final ValueChanged<DocumentEntry> onStartSelection;

  static const _grid2Col = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: AppSpacing.sm,
    mainAxisSpacing: AppSpacing.sm,
    childAspectRatio: 0.72,
  );
  static const _grid3Col = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    crossAxisSpacing: AppSpacing.sm,
    mainAxisSpacing: AppSpacing.sm,
    childAspectRatio: 0.72,
  );

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.crossAxisExtent >= 620 ? 3 : 2;
        return SliverGrid(
          key: const ValueKey('library_shelf_grid'),
          gridDelegate: columns == 2 ? _grid2Col : _grid3Col,
          delegate: SliverChildBuilderDelegate((context, index) {
            final document = documents[index];
            return AnimatedSwitcher(
              duration: AppMotion.normal,
              reverseDuration: AppMotion.fast,
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: AppMotion.enter,
                  reverseCurve: AppMotion.exit,
                );
                return FadeTransition(
                  opacity: curved,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
                    child: child,
                  ),
                );
              },
              child: _ShelfDocumentCard(
                key: ValueKey('shelf_doc_${document.path}'),
                document: document,
                selected: selectedPaths.contains(document.path),
                selectionActive: selectedPaths.isNotEmpty,
                onToggleSelection: onToggleSelection,
                onStartSelection: onStartSelection,
              ),
            );
          }, childCount: documents.length),
        );
      },
    );
  }
}

class _ShelfDocumentCard extends StatefulWidget {
  const _ShelfDocumentCard({
    required this.document,
    required this.selected,
    required this.selectionActive,
    required this.onToggleSelection,
    required this.onStartSelection,
    super.key,
  });

  final DocumentEntry document;
  final bool selected;
  final bool selectionActive;
  final ValueChanged<DocumentEntry> onToggleSelection;
  final ValueChanged<DocumentEntry> onStartSelection;

  @override
  State<_ShelfDocumentCard> createState() => _ShelfDocumentCardState();
}

class _ShelfDocumentCardState extends State<_ShelfDocumentCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: AppMotion.fast,
      vsync: this,
    );
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _pressController, curve: AppMotion.press),
    );
  }

  void _springBack() {
    _pressController.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 28),
        _pressController.value,
        0,
        0,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cover = _CoverStyle.forDocument(widget.document);
    return Semantics(
      label: widget.document.name,
      hint: widget.selectionActive ? '双击切换选择' : '双击打开阅读，长按多选',
      button: true,
      selected: widget.selected,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _pressAnimation,
          builder: (context, child) {
            return Transform.scale(scale: _pressAnimation.value, child: child);
          },
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.selectionActive
                  ? () => widget.onToggleSelection(widget.document)
                  : () => _openDocument(context),
              onLongPress: () => _handleLongPress(context),
              onTapDown: (_) => _pressController.forward(),
              onTapUp: (_) => _springBack(),
              onTapCancel: _springBack,
              splashFactory: NoSplash.splashFactory,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cover.start, cover.end],
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(
                    color: cover.border.withValues(alpha: 0.55),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 18,
                        color: cover.spine.withValues(alpha: 0.72),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _ShelfTypeMark(document: widget.document),
                              if (widget.document.pinned) ...[
                                const SizedBox(width: AppSpacing.xs),
                                const Icon(
                                  Icons.push_pin_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                          const Spacer(),
                          Text(
                            widget.document.name,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: cover.foreground,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _DocumentMetaRow(
                            tags: widget.document.tags,
                            summary: _documentSummary(widget.document),
                          ),
                        ],
                      ),
                    ),
                    if (widget.selectionActive)
                      Positioned(
                        right: AppSpacing.sm,
                        top: AppSpacing.sm,
                        child: Icon(
                          widget.selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
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

  void _handleLongPress(BuildContext context) {
    if (widget.selectionActive) {
      widget.onToggleSelection(widget.document);
      return;
    }
    HapticService.mediumImpact();
    widget.onStartSelection(widget.document);
    _springBack();
  }
}

class _ShelfTypeMark extends StatelessWidget {
  const _ShelfTypeMark({required this.document});

  final DocumentEntry document;

  @override
  Widget build(BuildContext context) {
    final isMd = document.type == DocumentType.markdown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMd ? Icons.description_rounded : Icons.code_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            document.type.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverStyle {
  const _CoverStyle({
    required this.start,
    required this.end,
    required this.spine,
    required this.border,
    required this.foreground,
  });

  final Color start;
  final Color end;
  final Color spine;
  final Color border;
  final Color foreground;

  static const _styles = [
    _CoverStyle(
      start: Color(0xFF2F5C8F),
      end: Color(0xFF16324F),
      spine: Color(0xFF0E2238),
      border: Color(0xFF5E89B9),
      foreground: Colors.white,
    ),
    _CoverStyle(
      start: Color(0xFF7A5C38),
      end: Color(0xFF3E2F22),
      spine: Color(0xFF2A2018),
      border: Color(0xFFB18A5B),
      foreground: Colors.white,
    ),
    _CoverStyle(
      start: Color(0xFF346B57),
      end: Color(0xFF183D32),
      spine: Color(0xFF102A23),
      border: Color(0xFF69A58B),
      foreground: Colors.white,
    ),
    _CoverStyle(
      start: Color(0xFF6A4D7D),
      end: Color(0xFF33243E),
      spine: Color(0xFF241A2C),
      border: Color(0xFFA487B7),
      foreground: Colors.white,
    ),
    _CoverStyle(
      start: Color(0xFF8A4B42),
      end: Color(0xFF472620),
      spine: Color(0xFF301A16),
      border: Color(0xFFC17A70),
      foreground: Colors.white,
    ),
    _CoverStyle(
      start: Color(0xFF4C6171),
      end: Color(0xFF24313A),
      spine: Color(0xFF182129),
      border: Color(0xFF8199AA),
      foreground: Colors.white,
    ),
  ];

  static _CoverStyle forDocument(DocumentEntry document) {
    final source = '${document.path}/${document.name}/${document.type.name}';
    final hash = source.codeUnits.fold<int>(
      0,
      (value, unit) => (value * 31 + unit) & 0x7fffffff,
    );
    return _styles[hash % _styles.length];
  }
}
