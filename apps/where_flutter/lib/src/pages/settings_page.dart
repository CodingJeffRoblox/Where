import 'dart:io';

import 'package:flutter/material.dart';

import '../actions.dart';
import '../browser_bridge.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final stats = state.stats();
    final byKind = <String, int>{
      for (final e in (stats['by_kind'] as List<dynamic>))
        (e as List<dynamic>)[0] as String: (e[1] as num).toInt(),
    };
    final folders = state.indexedFolders();

    Widget section(int i, String title, String subtitle, Widget child) => FadeSlideIn(
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  child,
                ]),
              ),
            ),
          ),
        );

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const PageHeader(title: 'Settings', subtitle: 'Appearance, your data, and privacy.'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              section(
                0,
                'Appearance',
                'Where follows your system theme unless you pick one.',
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('System')),
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                  ],
                  selected: {state.themeMode},
                  onSelectionChanged: (s) => state.setTheme(s.first),
                ),
              ),
              section(
                1,
                'Privacy',
                'Everything Where knows, and where it lives.',
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _Count('Objects', (stats['objects'] as num).toInt()),
                    _Count('Connections', (stats['relations'] as num).toInt()),
                    _Count('Files', (byKind['file'] ?? 0) + (byKind['image'] ?? 0) + (byKind['video'] ?? 0)),
                    _Count('Notes', byKind['note'] ?? 0),
                    _Count('Tasks', byKind['task'] ?? 0),
                    _Count('Folders indexed', folders.length),
                  ]),
                  const SizedBox(height: 18),
                  const _Toggle(Icons.cloud_off_outlined, 'Cloud sync', 'Off — not built yet. Your data stays on this computer.'),
                  const _Toggle(Icons.smart_toy_outlined, 'AI features', 'Off — Where works fully without AI.'),
                  const _Toggle(Icons.history_toggle_off, 'Activity tracking', 'Off — Where does not watch what you do.'),
                  const _Toggle(Icons.visibility_off_outlined, 'Screen capture', 'Never.'),
                  const SizedBox(height: 8),
                  Text('Database: ${state.core.dbPath}',
                      style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ]),
              ),
              section(
                2,
                'Browser',
                'Save pages from Chrome, Edge or Brave straight into Where, with a title, a note and a project.',
                const _BrowserCard(),
              ),
              section(
                2,
                'Indexed folders',
                'Only these folders are searched. Files are never moved, changed or uploaded.',
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (folders.isEmpty)
                    Text('No folders yet.', style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
                  else
                    for (final f in folders)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.folder_outlined, color: scheme.primary),
                        title: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          tooltip: 'Open folder',
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          onPressed: () => openPath(context, f),
                        ),
                      ),
                  const SizedBox(height: 10),
                  Row(children: [
                    FilledButton.tonalIcon(
                      onPressed: state.indexing ? null : () => pickAndIndexFolder(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add a folder'),
                    ),
                    const SizedBox(width: 8),
                    if (folders.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: state.indexing ? null : state.refreshAllFolders,
                        icon: const Icon(Icons.sync, size: 18),
                        label: const Text('Refresh all'),
                      ),
                  ]),
                ]),
              ),
              section(
                3,
                'Export',
                'Your data is yours. Take a full copy with every connection preserved.',
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    onPressed: () => pickAndExport(context, 'json'),
                    icon: const Icon(Icons.data_object, size: 18),
                    label: const Text('JSON'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => pickAndExport(context, 'md'),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Markdown'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => pickAndExport(context, 'sqlite'),
                    icon: const Icon(Icons.storage_outlined, size: 18),
                    label: const Text('Database copy'),
                  ),
                ]),
              ),
              section(
                4,
                'Keyboard shortcuts',
                'Everything can be done from the keyboard.',
                const Column(children: [
                  _Shortcut('Ctrl K', 'Quick actions and search'),
                  _Shortcut('Ctrl 1 – 6', 'Home, Projects, Tasks, Notes, Links, Files'),
                  _Shortcut('Ctrl ,', 'Settings'),
                  _Shortcut('↑ ↓  Enter', 'Move through results and open'),
                  _Shortcut('Esc', 'Close a dialog'),
                ]),
              ),
              FadeSlideIn(
                index: 5,
                child: Center(
                  child: Text('Where 0.4.0 · alpha · local-first',
                      style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 700),
          curve: WhereTheme.curve,
          builder: (_, v, __) => Text('${v.round()}', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ),
        Text(label, style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Pill('Off', color: Colors.green.shade600, icon: Icons.lock_outline),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(this.keys, this.label);

  final String keys;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(keys, style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 14),
        Text(label, style: t.bodyMedium),
      ]),
    );
  }
}

class _BrowserCard extends StatelessWidget {
  const _BrowserCard();

  /// The setup scripts copy the extension next to the app:
  /// beside Where.exe / the Linux binary, or in Where.app/Contents/Resources.
  static String _extensionFolder() {
    final sep = Platform.pathSeparator;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final base = Platform.isMacOS ? '$exeDir$sep..${sep}Resources' : exeDir;
    return Directory('$base${sep}browser-extension').absolute.path;
  }

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final bridge = state.bridge;
    final folder = _extensionFolder();
    final folderExists = Directory(folder).existsSync();

    final status = bridge.error != null
        ? Pill('Not available', color: scheme.error, icon: Icons.error_outline)
        : bridge.running
            ? Pill('Ready on this computer', color: statusColor(context, 'done'), icon: Icons.check)
            : const Pill('Starting…');

    Widget step(int n, String title, Widget body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: scheme.primary.withAlpha(30), shape: BoxShape.circle),
              child: Text('$n', style: t.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                body,
              ]),
            ),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        status,
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            bridge.error ?? 'Only this computer can connect (port ${BrowserBridge.port}). Nothing is sent to the internet.',
            style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ]),
      const SizedBox(height: 18),
      step(
        1,
        'Open your browser’s extensions page and turn on Developer mode',
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final page in const ['chrome://extensions', 'edge://extensions', 'brave://extensions'])
            ActionChip(
              avatar: const Icon(Icons.content_copy_rounded, size: 14),
              label: Text(page),
              onPressed: () => copyText(context, page, what: 'Address'),
            ),
          Text('Copy, then paste into the address bar.', style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      ),
      step(
        2,
        'Click “Load unpacked” and choose the Where extension folder',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText(folder, style: t.bodySmall?.copyWith(fontFamily: 'monospace')),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              onPressed: folderExists ? () => openPath(context, folder) : null,
              icon: const Icon(Icons.folder_open_outlined, size: 16),
              label: const Text('Show folder'),
            ),
            TextButton.icon(
              onPressed: () => copyText(context, folder, what: 'Folder path'),
              icon: const Icon(Icons.content_copy_rounded, size: 16),
              label: const Text('Copy path'),
            ),
          ]),
          if (!folderExists)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Not found here yet — run start-where.bat once more, or use the browser-extension folder in the Where source code.',
                style: t.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
        ]),
      ),
      step(
        3,
        'Pin the Where button, open any web page, click it, then click Connect',
        Text(
          'Where will ask you to allow the connection. After that, save any page with a click or Alt+Shift+W — '
          'or right-click a page or link and choose “Save to Where”.',
          style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      const Divider(height: 24),
      Text('Connected browsers', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      if (state.browserClients.isEmpty)
        Text('None yet.', style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
      else
        for (final c in state.browserClients)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.public, color: scheme.primary),
            title: Text(c.name),
            subtitle: Text('Connected ${timeAgo(c.added)}'),
            trailing: TextButton(
              onPressed: () => state.disconnectBrowser(c),
              child: const Text('Disconnect'),
            ),
          ),
    ]);
  }
}
