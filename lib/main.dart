import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app.dart';
import 'core/document_file_service.dart';
import 'core/widgets/liquid_glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  // Sweep parked deletions older than the undo window; a failure here must
  // never block startup, so it is fire-and-forget.
  unawaited(DocumentFileService.purgeExpiredTrash());
  // Safety net for library widgets that are not handed explicit
  // settings by one of the app wrappers; app surfaces resolve their
  // own AppGlassSettings role.
  LiquidGlassWidgets.globalSettings = AppGlassSettings.fallbackGlobal();
  runZonedGuarded(
    () {
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('[GlobalError] ${details.exceptionAsString()}');
        if (details.stack != null) {
          debugPrint(details.stack.toString());
        }
      };
      ErrorWidget.builder = (details) {
        return _GlobalErrorCard(details: details);
      };
      runApp(
        LiquidGlassWidgets.wrap(
          child: const _RestartableApp(child: JianxiReaderApp()),
          brightnessResolver: Theme.maybeBrightnessOf,
        ),
      );
    },
    (error, stackTrace) {
      debugPrint('[GlobalError] uncaught async error: $error');
      debugPrint(stackTrace.toString());
    },
  );
}

class _RestartableApp extends StatefulWidget {
  const _RestartableApp({required this.child});

  final Widget child;

  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_RestartableAppState>()?.restart();
  }

  @override
  State<_RestartableApp> createState() => _RestartableAppState();
}

class _RestartableAppState extends State<_RestartableApp> {
  Key _key = UniqueKey();

  void restart() {
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

class _GlobalErrorCard extends StatelessWidget {
  const _GlobalErrorCard({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final dark =
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF1D1D1F);
    return Material(
      color: dark ? const Color(0xFF0A0A0C) : const Color(0xFFF8F1E6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '页面暂时无法显示',
                          style: TextStyle(
                            color: foreground,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    details.exceptionAsString(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: foreground, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _RestartableApp.restart(context),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重试'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
