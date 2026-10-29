import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets/liquid_glass.dart';

/// Shows the "what 3.0 is" card once, then never again.
///
/// The audit's product complaint was that 3.0 had no one-sentence claim; this is
/// the card that states it, plus the data warning the README promises
/// ("data lives on this device, uninstalling loses it").
class WhatsNewGate extends StatefulWidget {
  const WhatsNewGate({required this.child, super.key});

  final Widget child;

  static const String seenKey = 'onboarding.whatsNew3_0';

  @override
  State<WhatsNewGate> createState() => _WhatsNewGateState();
}

class _WhatsNewGateState extends State<WhatsNewGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    // Debug builds (including widget tests) skip onboarding: a modal over the
    // library would block every test that pumps the app.
    if (kDebugMode) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(WhatsNewGate.seenKey) ?? false) return;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => GlassDialog(
          title: '简兮 3.0',
          message:
              '把你散落在手机里的 Markdown 笔记，变成一个读得完、找得到、不丢的本地知识库。\n\n'
              '· 文件夹导入：保留目录与图片，相对链接照样能用\n'
              '· 阅读痕迹：书签和历史集中在一处，一键回到那句话\n'
              '· 全文搜索：输入一个词，直达正文里的那句话\n'
              '· 更安心：误删 10 秒内可撤销，损坏文件不扩散\n\n'
              '数据只保存在本机。卸载应用或换手机会一并丢失，请自行保留源文件。',
          maxWidth: 340,
          settings: AppGlassSettings.build(
            dialogContext,
            role: AppGlassRole.staticPanel,
          ),
          quality: AppGlassSettings.qualityFor(AppGlassRole.staticPanel),
          actions: [
            GlassDialogAction(
              label: '开始使用',
              isPrimary: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      );
      await preferences.setBool(WhatsNewGate.seenKey, true);
    } catch (error) {
      debugPrint('[WhatsNewGate] skipped: $error');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
