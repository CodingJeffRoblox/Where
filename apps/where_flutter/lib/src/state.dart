import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';

import 'browser_bridge.dart';
import 'models.dart';
import 'where_core.dart';

enum Section { home, projects, tasks, notes, links, files, settings }

extension SectionInfo on Section {
  String get label => const {
        Section.home: 'Home',
        Section.projects: 'Projects',
        Section.tasks: 'Tasks',
        Section.notes: 'Notes',
        Section.links: 'Links',
        Section.files: 'Files',
        Section.settings: 'Settings',
      }[this]!;

  IconData get icon => const {
        Section.home: Icons.search_rounded,
        Section.projects: Icons.folder_special_outlined,
        Section.tasks: Icons.check_circle_outline,
        Section.notes: Icons.sticky_note_2_outlined,
        Section.links: Icons.link_rounded,
        Section.files: Icons.insert_drive_file_outlined,
        Section.settings: Icons.tune_rounded,
      }[this]!;

  IconData get selectedIcon => const {
        Section.home: Icons.search_rounded,
        Section.projects: Icons.folder_special,
        Section.tasks: Icons.check_circle,
        Section.notes: Icons.sticky_note_2,
        Section.links: Icons.link_rounded,
        Section.files: Icons.insert_drive_file,
        Section.settings: Icons.tune_rounded,
      }[this]!;
}

/// App-wide state. Views call [bump] after a change so everything that
/// reads from the core refreshes.
class WhereState extends ChangeNotifier {
  WhereState(this.core, this._settingsFile) {
    _loadSettings();
  }

  final WhereCore core;
  final File _settingsFile;
  final messenger = GlobalKey<ScaffoldMessengerState>();
  final navigator = GlobalKey<NavigatorState>();
  late final bridge = BrowserBridge(this);

  int revision = 0;
  Section section = Section.home;
  ThemeMode themeMode = ThemeMode.system;
  bool indexing = false;
  String? indexingLabel;

  /// Browsers allowed to save links (see browser_bridge.dart).
  List<BrowserClient> browserClients = [];
  bool _pairingOpen = false;

  void bump() {
    revision++;
    notifyListeners();
  }

  void go(Section s) {
    if (section == s) return;
    section = s;
    navigator.currentState?.popUntil((r) => r.isFirst);
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
    _saveSettings();
  }

  void cycleTheme() {
    final order = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    setTheme(order[(order.indexOf(themeMode) + 1) % order.length]);
  }

  void toast(String message, {bool error = false}) {
    final m = messenger.currentState;
    if (m == null) return;
    final ctx = messenger.currentContext;
    final iconColor = ctx == null ? null : Theme.of(ctx).colorScheme.onInverseSurface;
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
      duration: Duration(seconds: error ? 5 : 2),
    ));
  }

  /// Runs a core call, turning errors into a friendly message.
  T? guard<T>(T Function() action, {String? success}) {
    try {
      final result = action();
      if (success != null) toast(success);
      bump();
      return result;
    } on WhereException catch (e) {
      toast(e.message, error: true);
      return null;
    }
  }

  // --------------------------------------------------------------- reads

  List<WObject> list(String kind, {int limit = 500}) => core
      .recent(kind: kind, limit: limit)
      .map((o) => WObject.fromJson(o as Map<String, dynamic>))
      .toList();

  List<Hit> search(String query, {int limit = 60}) {
    if (query.trim().isEmpty) return const [];
    try {
      final hits = (core.search(query, limit: limit)['hits'] as List<dynamic>)
          .map((h) => Hit.fromJson(h as Map<String, dynamic>))
          .toList();
      hits.sort((a, b) => a.object.info.rank.compareTo(b.object.info.rank));
      return hits;
    } on WhereException {
      return const [];
    }
  }

  Detail? detail(String id) {
    try {
      return Detail.fromJson(core.get(id));
    } on WhereException {
      return null;
    }
  }

  Map<String, dynamic> stats() => core.stats();

  List<String> indexedFolders() =>
      core.indexRoots().map((r) => (r as Map<String, dynamic>)['path'] as String).toList();

  // -------------------------------------------------------------- writes

  WObject? create(String kind, String title, {String? projectId, String body = ''}) {
    final props = kind == 'task' ? <String, dynamic>{'status': 'todo'} : null;
    final json = guard(
      () => core.create(kind, title, body: body, projectId: projectId, properties: props),
      success: '${KindInfo.of(kind).singular} created',
    );
    return json == null ? null : WObject.fromJson(json);
  }

  void setStatus(WObject task, String status) =>
      guard(() => core.update(task.id, properties: {'status': status}));

  void rename(WObject o, String title) => guard(() => core.update(o.id, title: title));

  void saveBody(WObject o, String body) {
    try {
      core.update(o.id, body: body);
      revision++; // quiet save: no toast, no full rebuild while typing
    } on WhereException catch (e) {
      toast(e.message, error: true);
    }
  }

  void delete(WObject o) => guard(() => core.delete(o.id), success: '"${o.title}" removed from Where');

  void moveToProject(WObject o, WObject? from, WObject? to) => guard(() {
        if (from != null) core.relate(from.id, o.id, remove: true);
        if (to != null) core.relate(to.id, o.id);
      }, success: to == null ? 'Removed from project' : 'Added to ${to.title}');

  /// Indexes in a background isolate so the window stays responsive.
  Future<void> indexFolder(String path) async {
    if (indexing) return;
    indexing = true;
    indexingLabel = path;
    notifyListeners();
    final db = core.dbPath;
    final lib = core.libraryPath;
    try {
      final report = await Isolate.run(() {
        final c = WhereCore.open(db, libraryPath: lib);
        try {
          return c.indexFolder(path);
        } finally {
          c.close();
        }
      });
      toast('Indexed ${report['scanned']} files — ${report['added']} new, '
          '${report['updated']} updated, ${report['removed']} removed');
    } on WhereException catch (e) {
      toast(e.message, error: true);
    } catch (e) {
      toast('Indexing failed: $e', error: true);
    } finally {
      indexing = false;
      indexingLabel = null;
      bump();
    }
  }

  Future<void> refreshAllFolders() async {
    if (indexing) return;
    indexing = true;
    indexingLabel = 'all folders';
    notifyListeners();
    final db = core.dbPath;
    final lib = core.libraryPath;
    try {
      final reports = await Isolate.run(() {
        final c = WhereCore.open(db, libraryPath: lib);
        try {
          return c.reindexAll();
        } finally {
          c.close();
        }
      });
      toast('Refreshed ${reports.length} folder${reports.length == 1 ? '' : 's'}');
    } on WhereException catch (e) {
      toast(e.message, error: true);
    } catch (e) {
      toast('Refresh failed: $e', error: true);
    } finally {
      indexing = false;
      indexingLabel = null;
      bump();
    }
  }

  String? export(String format, String directory) {
    final stamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
    final ext = format == 'md' ? 'md' : format;
    final path = '$directory${Platform.pathSeparator}where-export-$stamp.$ext';
    return guard(() => core.export(format, path), success: 'Exported to $path');
  }

  // ---------------------------------------------------------------- links

  WObject? findLink(String url) {
    try {
      final j = core.findSource(LinkInfo.sourceKey(url));
      return j == null ? null : WObject.fromJson(j);
    } on WhereException {
      return null;
    }
  }

  /// Saves a web link. Saving the same address again updates it.
  /// A null [note] keeps the existing note (e.g. right-click saves).
  WObject saveLink({
    required String url,
    String title = '',
    String? note,
    String? projectId,
    String source = 'Where',
  }) {
    if (!LinkInfo.isWebUrl(url)) {
      throw WhereException('Only web addresses (http:// or https://) can be saved.');
    }
    final clean = LinkInfo.normalize(url);
    final existing = findLink(clean);
    final t = title.trim().isEmpty ? (existing?.title ?? LinkInfo.domain(clean)) : title.trim();
    final json = core.create(
      'bookmark',
      t,
      body: note ?? existing?.body ?? '',
      projectId: projectId,
      sourceKey: LinkInfo.sourceKey(clean),
      properties: {
        'url': clean,
        'domain': LinkInfo.domain(clean),
        'saved_from': source,
      },
    );
    bump();
    return WObject.fromJson(json);
  }

  /// Asks the person at the computer whether a browser may connect.
  /// Returns a new access token, or null if declined.
  Future<String?> requestBrowserPairing(String client) async {
    final ctx = navigator.currentContext;
    if (ctx == null || _pairingOpen) return null;
    _pairingOpen = true;
    try {
      final allowed = await showDialog<bool>(
        context: ctx,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.link_rounded),
          title: Text('Connect $client to Where?'),
          content: const SizedBox(
            width: 400,
            child: Text(
              'The Where browser extension wants to save links into Where.\n\n'
              'Only allow this if you just clicked Connect in your browser. '
              'You can disconnect it any time in Settings.',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Deny')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Allow')),
          ],
        ),
      );
      if (allowed != true) return null;
      final rnd = Random.secure();
      final token = List.generate(32, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      browserClients = [
        ...browserClients,
        BrowserClient(name: client, token: token, added: DateTime.now()),
      ];
      _saveSettings();
      toast('$client is connected. Save pages with the Where button in your browser.');
      notifyListeners();
      return token;
    } finally {
      _pairingOpen = false;
    }
  }

  bool isBrowserToken(String? token) =>
      token != null && token.isNotEmpty && browserClients.any((c) => c.token == token);

  void disconnectBrowser(BrowserClient client) {
    browserClients = browserClients.where((c) => c.token != client.token).toList();
    _saveSettings();
    toast('${client.name} disconnected');
    notifyListeners();
  }

  // ------------------------------------------------------------ settings

  void _loadSettings() {
    try {
      if (!_settingsFile.existsSync()) return;
      final j = jsonDecode(_settingsFile.readAsStringSync()) as Map<String, dynamic>;
      themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == j['theme'],
        orElse: () => ThemeMode.system,
      );
      browserClients = ((j['browsers'] as List<dynamic>?) ?? const [])
          .map((b) => BrowserClient.fromJson(b as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupt settings are not worth crashing over; defaults apply.
    }
  }

  void _saveSettings() {
    try {
      _settingsFile.writeAsStringSync(jsonEncode({
        'theme': themeMode.name,
        'browsers': browserClients.map((b) => b.toJson()).toList(),
      }));
    } catch (_) {}
  }
}

/// Makes [WhereState] available to every widget below it.
class WhereScope extends InheritedNotifier<WhereState> {
  const WhereScope({super.key, required WhereState state, required super.child})
      : super(notifier: state);

  static WhereState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WhereScope>()!.notifier!;

  /// Access without subscribing to rebuilds (for callbacks).
  static WhereState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<WhereScope>()!.notifier!;
}

/// A browser that was allowed to save links into Where.
class BrowserClient {
  const BrowserClient({required this.name, required this.token, required this.added});

  factory BrowserClient.fromJson(Map<String, dynamic> j) => BrowserClient(
        name: j['name'] as String? ?? 'Browser',
        token: j['token'] as String? ?? '',
        added: DateTime.tryParse(j['added'] as String? ?? '') ?? DateTime.now(),
      );

  final String name;
  final String token;
  final DateTime added;

  Map<String, dynamic> toJson() => {'name': name, 'token': token, 'added': added.toIso8601String()};
}
