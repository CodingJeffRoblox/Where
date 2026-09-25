import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/boot_screen.dart';
import 'src/shell.dart';
import 'src/state.dart';
import 'src/theme.dart';
import 'src/where_core.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Show the loading screen straight away; start Where behind it.
  runApp(const WhereRoot());
}

/// Runs startup behind an animated loading screen, then fades into the app.
class WhereRoot extends StatefulWidget {
  const WhereRoot({super.key});

  @override
  State<WhereRoot> createState() => _WhereRootState();
}

class _WhereRootState extends State<WhereRoot> {
  /// Keep the loading screen up at least this long so it never just flickers.
  static const _minimumBoot = Duration(milliseconds: 1100);

  WhereState? _ready;
  WhereState? _shown;
  String? _error;
  String _step = 'Starting…';
  double _progress = 0.05;
  ThemeMode _theme = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  void _set(String step, double progress) {
    if (mounted) setState(() {
      _step = step;
      _progress = progress;
    });
  }

  // Lets the loading screen paint between steps.
  Future<void> _breathe() => Future<void>.delayed(const Duration(milliseconds: 120));

  Future<void> _boot() async {
    final clock = Stopwatch()..start();
    try {
      _set('Finding your library…', 0.2);
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      final sep = Platform.pathSeparator;
      final settings = File('${dir.path}${sep}settings.json');
      _theme = _savedTheme(settings);
      await _breathe();

      _set('Starting the search engine…', 0.45);
      await _breathe();
      final core = WhereCore.open(
        '${dir.path}${sep}where.db',
        libraryPath: Platform.environment['WHERE_FFI_LIB'],
      );

      _set('Loading your projects and notes…', 0.7);
      await _breathe();
      final state = WhereState(core, settings);

      _set('Connecting your browser…', 0.88);
      // Lets the Where browser extension save links (127.0.0.1 only).
      await state.bridge.start();

      _set('Ready', 1);
      final left = _minimumBoot - clock.elapsed;
      if (left > Duration.zero) await Future<void>.delayed(left);
      if (mounted) setState(() => _ready = state);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Reads the saved theme early so the loading screen matches the app.
  static ThemeMode _savedTheme(File settings) {
    try {
      final j = jsonDecode(settings.readAsStringSync()) as Map<String, dynamic>;
      return ThemeMode.values.firstWhere((m) => m.name == j['theme'], orElse: () => ThemeMode.system);
    } catch (_) {
      return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown != null) return WhereScope(state: shown, child: const WhereApp());
    if (_error != null) return WhereApp(startupError: _error);
    return MaterialApp(
      title: 'Where',
      debugShowCheckedModeBanner: false,
      theme: WhereTheme.light(),
      darkTheme: WhereTheme.dark(),
      themeMode: _theme,
      home: BootScreen(
        step: _step,
        progress: _progress,
        leaving: _ready != null,
        onLeft: () => setState(() => _shown = _ready),
      ),
    );
  }
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
                'The search engine (where_ffi) could not be loaded. Running the setup script again '
                'usually fixes this — start-where.bat on Windows, start-where.sh on Mac or Linux. '
                'It rebuilds the engine and puts it inside the app.',
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
