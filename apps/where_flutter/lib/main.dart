import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/shell.dart';
import 'src/state.dart';
import 'src/theme.dart';
import 'src/where_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WhereState? state;
  String? error;
  try {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final sep = Platform.pathSeparator;
    final core = WhereCore.open(
      '${dir.path}${sep}where.db',
      libraryPath: Platform.environment['WHERE_FFI_LIB'],
    );
    state = WhereState(core, File('${dir.path}${sep}settings.json'));
    // Lets the Where browser extension save links (127.0.0.1 only).
    unawaited(state.bridge.start());
  } catch (e) {
    error = '$e';
  }
  runApp(state == null ? WhereApp(startupError: error) : WhereScope(state: state, child: const WhereApp()));
}

class WhereApp extends StatelessWidget {
  const WhereApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    if (startupError != null) {
      return MaterialApp(
        title: 'Where',
        debugShowCheckedModeBanner: false,
        theme: WhereTheme.light(),
        darkTheme: WhereTheme.dark(),
        home: _StartupError(message: startupError!),
      );
    }
    final state = WhereScope.of(context);
    return MaterialApp(
      title: 'Where',
      debugShowCheckedModeBanner: false,
      theme: WhereTheme.light(),
      darkTheme: WhereTheme.dark(),
      themeMode: state.themeMode,
      themeAnimationDuration: WhereTheme.slow,
      scaffoldMessengerKey: state.messenger,
      home: const Shell(),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.error_outline, size: 40, color: scheme.error),
              const SizedBox(height: 16),
              Text('Where could not start', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                'The search engine (where_ffi) could not be loaded. Running start-where.bat again '
                'usually fixes this — it rebuilds the engine and puts it next to the app.',
                style: t.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(message, style: t.bodySmall?.copyWith(fontFamily: 'monospace')),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
