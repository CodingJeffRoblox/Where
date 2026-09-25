import 'package:flutter/material.dart';

import '../actions.dart';
import '../models.dart';
import '../state.dart';
import '../widgets.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final folders = state.indexedFolders();
    final files = [
      ...state.list('file', limit: 2000),
      ...state.list('image', limit: 2000),
      ...state.list('video', limit: 2000),
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final q = _filter.trim().toLowerCase();
    final shown = q.isEmpty
        ? files
        : files.where((f) => '${f.title} ${f.prop('path') ?? ''}'.toLowerCase().contains(q)).toList();

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          title: 'Files',
          subtitle: folders.isEmpty
              ? 'Only folders you choose are indexed. Your files are never moved or changed.'
              : '${files.length} files in ${folders.length} folder${folders.length == 1 ? '' : 's'}',
          actions: [
            if (folders.isNotEmpty)
              OutlinedButton.icon(
                onPressed: state.indexing ? null : state.refreshAllFolders,
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Refresh'),
              ),
            FilledButton.icon(
              onPressed: state.indexing ? null : () => pickAndIndexFolder(context),
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: const Text('Add a folder'),
            ),
          ],
        ),
        if (folders.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in folders)
                Tooltip(
                  message: f,
                  child: Chip(
                    avatar: Icon(Icons.folder_outlined, size: 16, color: scheme.primary),
                    label: Text(_short(f)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ]),
          ),
        if (files.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
            child: TextField(
              onChanged: (v) => setState(() => _filter = v),
              decoration: const InputDecoration(
                hintText: 'Filter by name or path…',
                prefixIcon: Icon(Icons.filter_list_rounded),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        Expanded(
          child: files.isEmpty
              ? EmptyState(
                  icon: Icons.folder_open_outlined,
                  title: state.indexing ? 'Indexing…' : 'No folders indexed yet',
                  message: 'Pick a folder — like Documents or a project folder — and Where will make '
                      'its files searchable. Nothing leaves your computer.',
                  actionLabel: state.indexing ? null : 'Add a folder',
                  onAction: () => pickAndIndexFolder(context),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  itemCount: shown.length,
                  itemBuilder: (ctx, i) {
                    final f = shown[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: FadeSlideIn(
                        key: ValueKey(f.id),
                        index: i,
                        offset: 6,
                        child: HoverCard(
                          onTap: () => openDetail(context, f.id),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(children: [
                            KindIcon(f.kind, size: 30),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(f.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(_folderOf(f.prop('path') ?? ''),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                              ]),
                            ),
                            const SizedBox(width: 12),
                            Text(formatBytes(f.intProp('size')),
                                style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                            IconButton(
                              tooltip: 'Show in folder',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.open_in_new_rounded, size: 18),
                              onPressed: f.prop('path') == null
                                  ? null
                                  : () => openPath(context, f.prop('path')!, reveal: true),
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  static String _short(String path) {
    final parts = path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? path : parts.last;
  }

  static String _folderOf(String path) {
    final i = path.lastIndexOf(RegExp(r'[\\/]'));
    return i <= 0 ? path : path.substring(0, i);
  }
}
