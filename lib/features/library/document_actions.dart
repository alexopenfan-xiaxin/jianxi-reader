import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../core/document_error_describer.dart';
import '../../core/haptic_service.dart';
import '../../core/widgets/liquid_glass.dart';
import 'document_entry.dart';
import 'library_controller.dart';

Future<DocumentEntry?> showRenameDocumentDialog(
  BuildContext context,
  DocumentEntry document,
) {
  return showDialog<DocumentEntry>(
    context: context,
    builder: (context) => _RenameDocumentDialog(document: document),
  );
}

Future<bool> removeDocumentFromLibrary(
  BuildContext context,
  DocumentEntry document,
) async {
  final controller = context.read<LibraryController>();
  final messenger = ScaffoldMessenger.of(context);

  try {
    await controller.removeDocument(document);
    messenger.showSnackBar(SnackBar(content: Text('已移出 ${document.name}')));
    return true;
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('移出失败：${describeDocumentError(error)}')),
    );
    return false;
  }
}

class _RenameDocumentDialog extends StatefulWidget {
  const _RenameDocumentDialog({required this.document});

  final DocumentEntry document;

  @override
  State<_RenameDocumentDialog> createState() => _RenameDocumentDialogState();
}

class _RenameDocumentDialogState extends State<_RenameDocumentDialog> {
  late final TextEditingController _controller;
  late final GlobalKey<_ShakeBoxState> _shakeKey;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: p.basenameWithoutExtension(widget.document.name),
    );
    _shakeKey = GlobalKey<_ShakeBoxState>();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extension = p.extension(widget.document.name);
    final isLiquidGlass = liquidGlassEnabled(context);
    final textField = TextField(
      controller: _controller,
      autofocus: true,
      enabled: !_isSaving,
      decoration: InputDecoration(
        labelText: '文件名',
        suffixText: extension,
        errorText: _errorText,
        border: isLiquidGlass ? InputBorder.none : null,
        enabledBorder: isLiquidGlass ? InputBorder.none : null,
        focusedBorder: isLiquidGlass ? InputBorder.none : null,
        filled: isLiquidGlass ? false : null,
        isDense: isLiquidGlass,
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
    );

    return LiquidGlassDialog(
      title: const Text('重命名文档'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShakeBox(
            key: _shakeKey,
            child: isLiquidGlass
                ? LiquidGlassTextFieldFrame(child: textField)
                : textField,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '扩展名保持不变',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.palette.muted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? '保存中' : '保存'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final controller = context.read<LibraryController>();
      final renamed = await controller.renameDocument(
        widget.document,
        _controller.text,
      );
      if (mounted) {
        Navigator.of(context).pop(renamed);
      }
    } catch (error) {
      if (mounted) {
        HapticService.mediumImpact();
        _shakeKey.currentState?.shake();
        setState(() {
          _isSaving = false;
          _errorText = describeDocumentError(error);
        });
      }
    }
  }
}

/// Translates its child with a decaying zigzag when [shake] is called.
/// One-shot per call; the child subtree is never remounted, so a [TextField]
/// inside keeps its focus and text state.
class _ShakeBox extends StatefulWidget {
  const _ShakeBox({required this.child, super.key});

  final Widget child;

  @override
  State<_ShakeBox> createState() => _ShakeBoxState();
}

class _ShakeBoxState extends State<_ShakeBox>
    with SingleTickerProviderStateMixin {
  static const _travel = 8.0;
  static const _cycles = 2.0;

  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 380),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standard,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void shake() {
    if (mounted) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;
        final decay = 1 - t;
        final angle = t * math.pi * 2 * _cycles;
        final offset = math.sin(angle) * _travel * decay;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
