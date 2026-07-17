import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
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
      runApp(const _RestartableApp(child: JianxiReaderApp()));
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
    return Material(
      color: const Color(0xFFF8F1E6),
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
                  const Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '页面暂时无法显示',
                          style: TextStyle(
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
                    style: const TextStyle(fontSize: 13),
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
