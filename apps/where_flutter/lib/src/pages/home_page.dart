import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../actions.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<Hit> _hits = const [];
  int _selected = 0;
  Duration? _elapsed;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      final sw = Stopwatch()..start();
      final hits = WhereScope.read(context).search(q);
      sw.stop();
      setState(() {
        _hits = hits;
        _selected = 0;
        _elapsed = sw.elapsed;
      });
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if ((e is! KeyDownEvent && e is! KeyRepeatEvent) || _hits.isEmpty) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _selected = (_selected + 1).clamp(0, _hits.length - 1).toInt());
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _selected = (_selected - 1).clamp(0, _hits.length - 1).toInt());
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter) {
      openDetail(context, _hits[_selected].object.id);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Working late';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context); // rebuild when data changes
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final searching = _controller.text.trim().isNotEmpty;

    // Re-run the current search after edits elsewhere (e.g. a task was renamed).
    if (searching && state.revision != _lastRevision) {
      _lastRevision = state.revision;
      WidgetsBinding.instance.addPostFrameCallback((_) => _onChanged(_controller.text));
    }

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FadeSlideIn(
                child: Text(_greeting(), style: t.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ),
              const SizedBox(height: 4),
              FadeSlideIn(
                index: 1,
                child: Text('What are you looking for?',
                    style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                index: 2,
                child: Focus(
                  onKeyEvent: _onKey,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: true,
                    onChanged: (q) {
                      setState(() {});
                      _onChanged(q);
                    },
                    style: t.titleMedium,
                    decoration: InputDecoration(
                      hintText: 'Search projects, tasks, notes and files…',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 14, right: 8),
                        child: Icon(Icons.search_rounded, size: 24),
                      ),
                      suffixIcon: AnimatedOpacity(
                        opacity: searching ? 1 : 0,
                        duration: WhereTheme.fast,
                        child: IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: searching
                              ? () {
                                  _controller.clear();
                                  setState(() => _hits = const []);
                                  _focus.requestFocus();
                                }
                              : null,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: WhereTheme.medium,
                switchInCurve: WhereTheme.curve,
                transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
                child: searching
                    ? KeyedSubtree(key: const ValueKey('results'), child: _results(context))
                    : KeyedSubtree(key: const ValueKey('overview'), child: _overview(context, state)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  int _lastRevision = -1;

  // ------------------------------------------------------------- results

  Widget _results(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (_hits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Nothing found for "${_controller.text.trim()}"',
          message: 'Try fewer or shorter words. Search matches the start of words, so "auth" finds "authentication".',
        ),
      );
    }
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
        child: Text(
          '${_hits.length} result${_hits.length == 1 ? '' : 's'}'
          '${_elapsed == null ? '' : ' · ${(_elapsed!.inMicroseconds / 1000).toStringAsFixed(1)} ms'}',
          style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    ];
    String? lastKind;
    for (var i = 0; i < _hits.length; i++) {
      final hit = _hits[i];
      if (hit.object.kind != lastKind) {
        lastKind = hit.object.kind;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(hit.object.info.plural.toUpperCase(),
              style: t.labelSmall?.copyWith(letterSpacing: 1.4, color: scheme.onSurfaceVariant)),
        ));
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: FadeSlideIn(
          key: ValueKey('${hit.object.id}-${_controller.text}'),
          index: i,
          offset: 8,
          duration: WhereTheme.medium,
          child: _ResultRow(
            hit: hit,
            query: _controller.text,
            selected: i == _selected,
            onTap: () => openDetail(context, hit.object.id),
          ),
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  // ------------------------------------------------------------ overview

  Widget _overview(BuildContext context, WhereState state) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final recent = state.list('', limit: 8).where((o) => o.kind != 'folder').toList();
    final stats = state.stats();
    final byKind = <String, int>{
      for (final e in (stats['by_kind'] as List<dynamic>))
        (e as List<dynamic>)[0] as String: (e[1] as num).toInt(),
    };
    int count(List<String> kinds) => kinds.fold(0, (sum, k) => sum + (byKind[k] ?? 0));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      FadeSlideIn(
        index: 3,
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          _QuickAction(Icons.create_new_folder_outlined, 'New project', () => newObject(context, 'project')),
          _QuickAction(Icons.add_task, 'New task', () => newObject(context, 'task')),
          _QuickAction(Icons.note_add_outlined, 'New note', () => newObject(context, 'note')),
          _QuickAction(Icons.folder_open_outlined, 'Index a folder', () => pickAndIndexFolder(context)),
        ]),
      ),
      const SizedBox(height: 28),
      FadeSlideIn(
        index: 4,
        child: Row(children: [
          _Stat('Projects', count(['project']), Section.projects),
          const SizedBox(width: 12),
          _Stat('Tasks', count(['task']), Section.tasks),
          const SizedBox(width: 12),
          _Stat('Notes', count(['note']), Section.notes),
          const SizedBox(width: 12),
          _Stat('Files', count(['file', 'image', 'video']), Section.files),
        ]),
      ),
      const SizedBox(height: 32),
      Text('Recent', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      if (recent.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Nothing here yet. Create a project or index a folder to get started.',
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        )
      else
        for (var i = 0; i < recent.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: FadeSlideIn(
              index: i + 5,
              child: _ObjectRow(object: recent[i], onTap: () => openDetail(context, recent[i].id)),
            ),
          ),
      const SizedBox(height: 20),
      Center(
        child: Text('Tip: press Ctrl K anywhere for quick actions',
            style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
      ),
    ]);
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.hit, required this.query, required this.selected, required this.onTap});

  final Hit hit;
  final String query;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = hit.object;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final subtitle = hit.viaContainer
        ? 'Contains ${hit.via.take(3).join(', ')}${hit.via.length > 3 ? '…' : ''}'
        : o.prop('path') ?? (o.body.isNotEmpty ? o.body.replaceAll('\n', ' ') : null);
    return HoverCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        KindIcon(o.kind),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              _highlight(o.title, query, t.bodyLarge!, scheme.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ]),
        ),
        if (o.kind == 'task') ...[
          const SizedBox(width: 10),
          Pill(statusLabel(o.status), color: statusColor(context, o.status)),
        ],
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant.withAlpha(selected ? 255 : 90)),
      ]),
    );
  }
}

/// Bolds the parts of [text] that start with any query word.
TextSpan _highlight(String text, String query, TextStyle base, Color accent) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return TextSpan(text: text, style: base);
  final lower = text.toLowerCase();
  final marks = List<bool>.filled(text.length, false);
  for (final w in words) {
    var start = 0;
    while (true) {
      final i = lower.indexOf(w, start);
      if (i < 0) break;
      final atWordStart = i == 0 || !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(lower[i - 1]);
      if (atWordStart) {
        for (var k = i; k < i + w.length && k < marks.length; k++) {
          marks[k] = true;
        }
      }
      start = i + 1;
    }
  }
  final spans = <TextSpan>[];
  var i = 0;
  while (i < text.length) {
    final on = marks[i];
    var j = i;
    while (j < text.length && marks[j] == on) {
      j++;
    }
    spans.add(TextSpan(
      text: text.substring(i, j),
      style: on ? base.copyWith(fontWeight: FontWeight.w800, color: accent) : base,
    ));
    i = j;
  }
  return TextSpan(children: spans);
}

class _ObjectRow extends StatelessWidget {
  const _ObjectRow({required this.object, required this.onTap});

  final WObject object;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return HoverCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        KindIcon(object.kind, size: 32),
        const SizedBox(width: 14),
        Expanded(child: Text(object.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyLarge)),
        Text('${object.info.singular} · ${timeAgo(object.updatedAt)}',
            style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 180,
      child: HoverCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Flexible(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.section);

  final String label;
  final int value;
  final Section section;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: HoverCard(
        onTap: () => WhereScope.read(context).go(section),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: WhereTheme.curve,
            builder: (_, v, __) =>
                Text('${v.round()}', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(label, style: t.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
