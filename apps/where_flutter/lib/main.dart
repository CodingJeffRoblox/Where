import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'src/where_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WhereCore? core;
  String? error;
  try {
    final dir = await getApplicationSupportDirectory();
    core = WhereCore.open('${dir.path}${Platform.pathSeparator}where.db',
        libraryPath: Platform.environment['WHERE_FFI_LIB']);
  } catch (e) {
    error = '$e';
  }
  runApp(WhereApp(core: core, startupError: error));
}

class WhereApp extends StatelessWidget {
  const WhereApp({super.key, this.core, this.startupError});
  final WhereCore? core;
  final String? startupError;

  @override
  Widget build(BuildContext context) {
    // Restrained UI (spec §30): neutral palette, no gradients or decoration.
    ThemeData theme(Brightness b) => ThemeData(
          brightness: b,
          colorSchemeSeed: const Color(0xFF4A5A6A),
          useMaterial3: true,
          visualDensity: VisualDensity.compact,
        );
    return MaterialApp(
      title: 'Where',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: core == null
          ? Scaffold(body: Center(child: Text('Where could not start.\n\n$startupError')))
          : SearchPage(core: core!),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.core});
  final WhereCore core;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<dynamic> _hits = const [];
  List<dynamic> _recent = const [];
  int _selected = 0;
  String? _status;

  static const _kindOrder = [
    'project', 'task', 'note', 'file', 'folder', 'person', 'application', 'website',
    'conversation', 'calendar_event', 'device', 'bookmark', 'image', 'video',
    'repository', 'organization',
  ];

  @override
  void initState() {
    super.initState();
    _refreshRecent();
  }

  void _refreshRecent() => setState(() => _recent = widget.core.recent(limit: 8));

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), () {
      final r = q.trim().isEmpty ? const [] : widget.core.search(q)['hits'] as List<dynamic>;
      final sorted = [...r]..sort((a, b) =>
          _kindOrder.indexOf(a['object']['kind']).compareTo(_kindOrder.indexOf(b['object']['kind'])));
      setState(() {
        _hits = sorted;
        _selected = 0;
      });
    });
  }

  Future<void> _indexFolder() async {
    final path = await getDirectoryPath(confirmButtonText: 'Index this folder');
    if (path == null) return;
    setState(() => _status = 'Indexing $path…');
    try {
      final r = widget.core.indexFolder(path);
      setState(() => _status = 'Indexed ${r['scanned']} files (${r['added']} new, ${r['removed']} removed).');
      _refreshRecent();
    } on WhereException catch (e) {
      setState(() => _status = e.message);
    }
  }

  Future<void> _quickCreate(String kind) async {
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: Text('New $kind'),
          content: TextField(controller: c, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Create')),
          ],
        );
      },
    );
    if (title == null || title.trim().isEmpty) return;
    widget.core.create(kind, title.trim());
    _refreshRecent();
    _onChanged(_controller.text);
  }

  void _open(Map<String, dynamic> obj) {
    final detail = widget.core.get(obj['id'] as String);
    showModalBottomSheet(
      context: context,
      builder: (_) => ObjectDetail(detail: detail),
    );
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent || _hits.isEmpty) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _selected = (_selected + 1).clamp(0, _hits.length - 1));
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _selected = (_selected - 1).clamp(0, _hits.length - 1));
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter) {
      _open(_hits[_selected]['object'] as Map<String, dynamic>);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final showingResults = _controller.text.trim().isNotEmpty;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WHERE', style: t.labelLarge?.copyWith(letterSpacing: 4)),
                const SizedBox(height: 16),
                Text('What are you looking for?', style: t.headlineSmall),
                const SizedBox(height: 12),
                Focus(
                  onKeyEvent: _onKey,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: true,
                    onChanged: _onChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search everything…  (try kind:task)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final k in ['project', 'task', 'note'])
                    ActionChip(label: Text('New $k'), onPressed: () => _quickCreate(k)),
                  ActionChip(
                      avatar: const Icon(Icons.folder_open, size: 16),
                      label: const Text('Index a folder'),
                      onPressed: _indexFolder),
                ]),
                if (_status != null)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status!, style: t.bodySmall)),
                const SizedBox(height: 16),
                Expanded(
                  child: showingResults ? _results(t) : _recentList(t),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _results(TextTheme t) {
    if (_hits.isEmpty) return Text('Nothing found.', style: t.bodyMedium);
    String? lastKind;
    return ListView.builder(
      itemCount: _hits.length,
      itemBuilder: (_, i) {
        final hit = _hits[i] as Map<String, dynamic>;
        final obj = hit['object'] as Map<String, dynamic>;
        final kind = obj['kind'] as String;
        final header = kind != lastKind;
        lastKind = kind;
        final via = (hit['via'] as List?)?.cast<String>() ?? const [];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (header)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(kind.replaceAll('_', ' ').toUpperCase(),
                  style: t.labelSmall?.copyWith(letterSpacing: 1.5)),
            ),
          ListTile(
            dense: true,
            selected: i == _selected,
            title: Text(obj['title'] as String),
            subtitle: via.isEmpty ? null : Text('contains ${via.join(', ')}'),
            onTap: () => _open(obj),
          ),
        ]);
      },
    );
  }

  Widget _recentList(TextTheme t) => ListView(children: [
        Text('Recent', style: t.titleSmall),
        for (final o in _recent)
          ListTile(
            dense: true,
            leading: Text((o['kind'] as String).toUpperCase(), style: t.labelSmall),
            title: Text(o['title'] as String),
            onTap: () => _open(o as Map<String, dynamic>),
          ),
      ]);
}

class ObjectDetail extends StatelessWidget {
  const ObjectDetail({super.key, required this.detail});
  final Map<String, dynamic> detail;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final obj = detail['object'] as Map<String, dynamic>;
    final related = detail['related'] as List<dynamic>;
    final props = (obj['properties'] as Map<String, dynamic>?) ?? const {};
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(children: [
        Text((obj['kind'] as String).toUpperCase(), style: t.labelSmall),
        Text(obj['title'] as String, style: t.titleLarge),
        const SizedBox(height: 8),
        for (final e in props.entries) Text('${e.key}: ${e.value}', style: t.bodySmall),
        if ((obj['body'] as String?)?.isNotEmpty ?? false)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(obj['body'] as String)),
        if (related.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Connected', style: t.titleSmall),
          for (final r in related)
            ListTile(
              dense: true,
              leading: Text(r['direction'] == 'outgoing' ? r['kind'] as String : 'part of',
                  style: t.labelSmall),
              title: Text(r['object']['title'] as String),
              subtitle: Text(r['object']['kind'] as String),
            ),
        ],
      ]),
    );
  }
}
