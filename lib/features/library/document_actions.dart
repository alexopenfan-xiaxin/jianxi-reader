import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
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
    messenger.showSnackBar(SnackBar(content: Text('移出失败：$error')));
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
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: p.basenameWithoutExtension(widget.document.name),
    );
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
          isLiquidGlass
              ? LiquidGlassTextFieldFrame(child: textField)
              : textField,
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
        setState(() {
          _isSaving = false;
          _errorText = error.toString();
        });
      }
    }
  }
}
