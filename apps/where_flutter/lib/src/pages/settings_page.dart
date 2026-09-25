import 'package:flutter/material.dart';

import '../actions.dart';
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
                  _Shortcut('Ctrl 1 – 5', 'Home, Projects, Tasks, Notes, Files'),
                  _Shortcut('Ctrl ,', 'Settings'),
                  _Shortcut('↑ ↓  Enter', 'Move through results and open'),
                  _Shortcut('Esc', 'Close a dialog'),
                ]),
              ),
              FadeSlideIn(
                index: 5,
                child: Center(
                  child: Text('Where 0.1 · pre-alpha · local-first',
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
