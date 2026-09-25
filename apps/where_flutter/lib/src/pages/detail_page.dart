import 'dart:async';

import 'package:flutter/material.dart';

import '../actions.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'links_page.dart';
import 'tasks_page.dart';

/// One object and everything connected to it.
class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context);
    final detail = state.detail(id);
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: detail == null
          ? Column(children: [
              const _TopBar(),
              const Expanded(
                child: EmptyState(
                  icon: Icons.delete_outline,
                  title: 'This item is gone',
                  message: 'It was removed from Where.',
                ),
              ),
            ])
          : _DetailBody(key: ValueKey(id), detail: detail),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.detail});

  final Detail? detail;

  @override
  Widget build(BuildContext context) {
    final o = detail?.object;
    final state = WhereScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 24, 0),
      child: Row(children: [
        IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 6),
        if (o != null) Pill(o.info.singular, icon: o.info.icon, color: o.info.color(context)),
        const Spacer(),
        if (o != null && (o.kind == 'task' || o.kind == 'note' || o.kind == 'folder' || o.kind == 'bookmark'))
          _ProjectMenu(object: o, current: detail!.parents.where((p) => p.kind == 'project').toList()),
        if (o != null && o.kind == 'bookmark' && o.prop('url') != null) ...[
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () => copyText(context, o.prop('url')!),
            icon: const Icon(Icons.content_copy_rounded, size: 16),
            label: const Text('Copy link'),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: () => openUrl(context, o.prop('url')!),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open in browser'),
          ),
        ],
        if (o != null && o.prop('path') != null) ...[
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () => openPath(context, o.prop('path')!, reveal: o.kind != 'folder'),
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: const Text('Show in folder'),
          ),
          if (o.kind != 'folder') ...[
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: () => openPath(context, o.prop('path')!),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open'),
            ),
          ],
        ],
        if (o != null) ...[
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Remove from Where',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final isFile = o.prop('path') != null;
              final ok = await confirm(
                context,
                title: 'Remove "${o.title}"?',
                message: isFile
                    ? 'This removes it from Where only. The file on your computer is not touched.'
                    : 'This deletes the ${o.info.singular.toLowerCase()} and its connections. This cannot be undone.',
              );
              if (ok && context.mounted) {
                Navigator.of(context).maybePop();
                state.delete(o);
              }
            },
          ),
        ],
      ]),
    );
  }
}

class _ProjectMenu extends StatelessWidget {
  const _ProjectMenu({required this.object, required this.current});

  final WObject object;
  final List<WObject> current;

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context);
    final projects = state.list('project');
    final now = current.isEmpty ? null : current.first;
    return PopupMenuButton<String>(
      tooltip: 'Move to a project',
      position: PopupMenuPosition.under,
      onSelected: (id) {
        if (id == '__none') {
          state.moveToProject(object, now, null);
        } else {
          state.moveToProject(object, now, projects.firstWhere((p) => p.id == id));
        }
      },
      itemBuilder: (_) => [
        if (projects.isEmpty)
          const PopupMenuItem(enabled: false, child: Text('No projects yet')),
        for (final p in projects)
          CheckedPopupMenuItem(value: p.id, checked: p.id == now?.id, child: Text(p.title)),
        if (now != null) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: '__none', child: Text('Remove from project')),
        ],
      ],
      child: Chip(
        avatar: const Icon(Icons.folder_special_outlined, size: 16),
        label: Text(now?.title ?? 'Add to project'),
      ),
    );
  }
}

class _DetailBody extends StatefulWidget {
  const _DetailBody({super.key, required this.detail});

  final Detail detail;

  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  final _titleFocus = FocusNode();
  Timer? _saveTimer;
  bool _saved = false;
  late WhereState _state;

  WObject get o => widget.detail.object;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: o.title);
    _body = TextEditingController(text: o.body);
    _titleFocus.addListener(_onTitleFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = WhereScope.read(context);
  }

  @override
  void dispose() {
    // Flush an unsaved edit when leaving the page.
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _state.saveBody(o, _body.text);
    }
    _titleFocus.removeListener(_onTitleFocus);
    _commitTitle(); // keep a title edit made just before leaving
    _title.dispose();
    _body.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _onTitleFocus() {
    if (!_titleFocus.hasFocus) _commitTitle();
  }

  void _commitTitle() {
    final v = _title.text.trim();
    if (v.isEmpty) {
      _title.text = o.title;
    } else if (v != o.title) {
      // Deferred: this can run while the page is being torn down.
      final obj = o;
      final state = _state;
      Future.microtask(() => state.rename(obj, v));
    }
  }

  void _onBodyChanged(String v) {
    _saveTimer?.cancel();
    setState(() => _saved = false);
    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _state.saveBody(o, v);
      setState(() => _saved = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final d = widget.detail;
    final editable = o.prop('path') == null; // files mirror the disk; keep them read-only

    final groups = <String, List<Related>>{};
    for (final r in d.related) {
      groups.putIfAbsent(r.label, () => []).add(r);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _TopBar(detail: d),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 12, 40, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FadeSlideIn(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 6), child: KindIcon(o.kind, size: 44)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: editable
                          ? TextField(
                              controller: _title,
                              focusNode: _titleFocus,
                              onSubmitted: (_) => _commitTitle(),
                              style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
                              maxLines: null,
                              decoration: const InputDecoration(
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isCollapsed: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 6),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: SelectableText(o.title,
                                  style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                            ),
                    ),
                  ]),
                ),
                if (o.kind == 'bookmark' && o.prop('url') != null)
                  FadeSlideIn(
                    index: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 60, top: 2),
                      child: Row(children: [
                        SiteAvatar(url: o.prop('url')!, size: 22),
                        const SizedBox(width: 8),
                        Flexible(child: UrlText(url: o.prop('url')!, style: t.bodyLarge, maxLines: 2)),
                      ]),
                    ),
                  ),
                const SizedBox(height: 6),
                FadeSlideIn(
                  index: 1,
                  child: Text(
                    '${o.prop('saved_from') != null && o.kind == 'bookmark' ? 'Saved from ${o.prop('saved_from')} · ' : ''}'
                    'Created ${timeAgo(o.createdAt)} · Updated ${timeAgo(o.updatedAt)}',
                    style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 22),
                if (o.kind == 'task')
                  FadeSlideIn(
                    index: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: SegmentedButton<String>(
                        segments: [
                          for (final s in taskStatuses)
                            ButtonSegment(
                              value: s,
                              label: Text(statusLabel(s)),
                              icon: Icon(
                                s == 'done'
                                    ? Icons.check_circle
                                    : s == 'in_progress'
                                        ? Icons.timelapse
                                        : Icons.radio_button_unchecked,
                                size: 18,
                              ),
                            ),
                        ],
                        selected: {o.status},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => WhereScope.read(context).setStatus(o, s.first),
                      ),
                    ),
                  ),
                if (!editable)
                  FadeSlideIn(index: 2, child: _FileFacts(object: o))
                else
                  FadeSlideIn(
                    index: 3,
                    child: Stack(children: [
                      TextField(
                        controller: _body,
                        onChanged: _onBodyChanged,
                        maxLines: null,
                        minLines: o.kind == 'note' ? 12 : (o.kind == 'bookmark' ? 6 : 4),
                        style: t.bodyLarge?.copyWith(height: 1.55),
                        decoration: InputDecoration(
                          hintText: o.kind == 'note'
                              ? 'Start writing…'
                              : o.kind == 'bookmark'
                                  ? 'Add a note about this site…'
                                  : 'Add details…',
                          contentPadding: const EdgeInsets.all(18),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 10,
                        child: AnimatedOpacity(
                          opacity: _saved ? 1 : 0,
                          duration: WhereTheme.medium,
                          child: Pill('Saved', icon: Icons.check, color: statusColor(context, 'done')),
                        ),
                      ),
                    ]),
                  ),
                const SizedBox(height: 28),
                if (o.kind == 'project')
                  FadeSlideIn(
                    index: 4,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        FilledButton.tonalIcon(
                          onPressed: () => newObject(context, 'task', project: o),
                          icon: const Icon(Icons.add_task, size: 18),
                          label: const Text('Add task'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => newObject(context, 'note', project: o),
                          icon: const Icon(Icons.note_add_outlined, size: 18),
                          label: const Text('Add note'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => showAddLinkDialog(context, project: o),
                          icon: const Icon(Icons.add_link, size: 18),
                          label: const Text('Add link'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _indexIntoProject(context),
                          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                          label: const Text('Add a folder'),
                        ),
                      ]),
                    ),
                  ),
                if (groups.isEmpty)
                  FadeSlideIn(
                    index: 5,
                    child: Text(
                      o.kind == 'project'
                          ? 'Nothing in this project yet. Add tasks, notes or a folder above.'
                          : 'Not connected to anything yet.',
                      style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 6),
                    child: Text(_capitalize(entry.key),
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  for (var i = 0; i < entry.value.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: FadeSlideIn(
                        index: i + 5,
                        child: entry.value[i].object.kind == 'task'
                            ? TaskRow(task: entry.value[i].object, showProject: false)
                            : entry.value[i].object.kind == 'bookmark'
                                ? LinkRow(link: entry.value[i].object, showProject: false)
                                : _RelatedRow(object: entry.value[i].object),
                      ),
                    ),
                  const SizedBox(height: 14),
                ],
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Future<void> _indexIntoProject(BuildContext context) async {
    // Index a folder, then attach its Folder object to this project.
    final state = WhereScope.read(context);
    final before = state.indexedFolders().toSet();
    await pickAndIndexFolder(context);
    final after = state.indexedFolders().where((f) => !before.contains(f)).toList();
    if (after.isEmpty) return;
    final folder = state.list('folder').where((f) => f.prop('path') == after.first).toList();
    if (folder.isNotEmpty) state.moveToProject(folder.first, null, o);
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _RelatedRow extends StatelessWidget {
  const _RelatedRow({required this.object});

  final WObject object;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final sub = object.prop('path') ?? (object.body.isNotEmpty ? object.body.replaceAll('\n', ' ') : null);
    return HoverCard(
      onTap: () => openDetail(context, object.id),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        KindIcon(object.kind, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(object.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (sub != null)
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
        Text(object.info.singular, style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant.withAlpha(120)),
      ]),
    );
  }
}

class _FileFacts extends StatelessWidget {
  const _FileFacts({required this.object});

  final WObject object;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final modified = DateTime.tryParse(object.prop('modified') ?? '');
    final hash = object.prop('hash');
    final rows = <(String, String)>[
      ('Location', object.prop('path') ?? ''),
      if (object.intProp('size') != null) ('Size', formatBytes(object.intProp('size'))),
      if (object.prop('mime') != null) ('Type', object.prop('mime')!),
      if (modified != null) ('Modified', timeAgo(modified)),
      if (hash != null) ('Fingerprint', hash.length > 26 ? '${hash.substring(0, 26)}…' : hash),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 110,
                  child: Text(r.$1, style: t.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                ),
                Expanded(child: SelectableText(r.$2, style: t.bodyMedium)),
              ]),
            ),
        ]),
      ),
    );
  }
}
