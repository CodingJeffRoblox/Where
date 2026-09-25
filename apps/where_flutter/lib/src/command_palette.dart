import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'actions.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class _Item {
  const _Item(this.icon, this.label, this.run, {this.hint, this.kind, this.keywords = ''});

  final IconData icon;
  final String label;
  final String? hint;
  final String? kind;
  final String keywords;
  final void Function(BuildContext context) run;
}

/// Ctrl+K: type to run an action or jump to anything in Where (spec §11).
Future<void> showCommandPalette(BuildContext context) {
  final state = WhereScope.read(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withAlpha(90),
    transitionDuration: WhereTheme.medium,
    pageBuilder: (ctx, _, __) => WhereScope(state: state, child: const _Palette()),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: WhereTheme.curve, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class _Palette extends StatefulWidget {
  const _Palette();

  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  int _selected = 0;
  List<_Item> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuild(''));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<_Item> _actions() {
    void close(BuildContext c) => Navigator.of(c).pop();
    void goTo(BuildContext c, Section s) {
      final st = WhereScope.read(c);
      close(c);
      st.go(s);
    }

    return [
      _Item(Icons.create_new_folder_outlined, 'New project', (c) {
        final root = WhereScope.read(c).navigator.currentContext!;
        close(c);
        newObject(root, 'project');
      }, keywords: 'create add'),
      _Item(Icons.add_task, 'New task', (c) {
        final root = WhereScope.read(c).navigator.currentContext!;
        close(c);
        newObject(root, 'task');
      }, keywords: 'create add todo'),
      _Item(Icons.note_add_outlined, 'New note', (c) {
        final root = WhereScope.read(c).navigator.currentContext!;
        close(c);
        newObject(root, 'note');
      }, keywords: 'create add write'),
      _Item(Icons.add_link, 'Add a link…', (c) {
        final root = WhereScope.read(c).navigator.currentContext!;
        close(c);
        showAddLinkDialog(root);
      }, keywords: 'bookmark website url save page'),
      _Item(Icons.folder_open_outlined, 'Index a folder…', (c) {
        final root = WhereScope.read(c).navigator.currentContext!;
        close(c);
        pickAndIndexFolder(root);
      }, keywords: 'add files scan import'),
      _Item(Icons.sync, 'Refresh indexed folders', (c) {
        final st = WhereScope.read(c);
        close(c);
        st.refreshAllFolders();
      }, keywords: 'reindex update scan'),
      for (final s in Section.values)
        _Item(s.icon, 'Go to ${s.label}', (c) => goTo(c, s), hint: 'Ctrl ${_shortcut(s)}', keywords: 'open show'),
      _Item(Icons.contrast, 'Switch theme', (c) {
        WhereScope.read(c).cycleTheme();
      }, keywords: 'dark light mode appearance'),
      _Item(Icons.download_outlined, 'Export everything (JSON)', (c) {
        final root = WhereScope.read(c).navigator.currentContext!;
        close(c);
        pickAndExport(root, 'json');
      }, keywords: 'backup save'),
    ];
  }

  static String _shortcut(Section s) =>
      s == Section.settings ? ',' : '${Section.values.indexOf(s) + 1}';

  void _rebuild(String q) {
    final state = WhereScope.read(context);
    final query = q.trim().toLowerCase();
    final actions = _actions()
        .where((a) => query.isEmpty || '${a.label} ${a.keywords}'.toLowerCase().contains(query))
        .toList();
    final objects = query.isEmpty
        ? state.list('', limit: 5)
        : state.search(query, limit: 8).map((h) => h.object).toList();
    final objectItems = objects
        .map((o) => _Item(
              o.info.icon,
              o.title,
              (c) {
                final root = WhereScope.read(c).navigator.currentContext!;
                Navigator.of(c).pop();
                openDetail(root, o.id);
              },
              hint: o.info.singular,
              kind: o.kind,
            ))
        .toList();
    setState(() {
      _items = query.isEmpty ? [...actions, ...objectItems] : [...objectItems, ...actions];
      _selected = 0;
    });
  }

  void _move(int delta) {
    if (_items.isEmpty) return;
    setState(() => _selected = (_selected + delta).clamp(0, _items.length - 1).toInt());
    const rowHeight = 46.0;
    final target = _selected * rowHeight;
    if (_scroll.hasClients) {
      final pos = _scroll.position;
      if (target < pos.pixels) {
        _scroll.animateTo(target, duration: WhereTheme.fast, curve: WhereTheme.curve);
      } else if (target + rowHeight > pos.pixels + pos.viewportDimension) {
        _scroll.animateTo(target + rowHeight - pos.viewportDimension,
            duration: WhereTheme.fast, curve: WhereTheme.curve);
      }
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter && _items.isNotEmpty) {
      _items[_selected].run(context);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Align(
      alignment: const Alignment(0, -0.55),
      child: Material(
        color: scheme.surfaceContainerHigh,
        elevation: 24,
        shadowColor: Colors.black.withAlpha(80),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 600,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Focus(
              onKeyEvent: _onKey,
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _rebuild,
                style: t.titleMedium,
                decoration: InputDecoration(
                  hintText: 'Type a command or search…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      widthFactor: 1,
                      child: Text('Esc', style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: _items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text('Nothing matches.', style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: _items.length,
                      itemExtent: 46,
                      itemBuilder: (ctx, i) => _row(ctx, i),
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: scheme.surfaceContainer,
              child: Row(children: [
                _key(context, '↑↓'),
                Text(' move   ', style: t.labelSmall),
                _key(context, 'Enter'),
                Text(' open   ', style: t.labelSmall),
                _key(context, 'Esc'),
                Text(' close', style: t.labelSmall),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int i) {
    final item = _items[i];
    final scheme = Theme.of(context).colorScheme;
    final selected = i == _selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _selected = i),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => item.run(context),
        child: AnimatedContainer(
          duration: WhereTheme.fast,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withAlpha(28) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            if (item.kind != null)
              KindIcon(item.kind!, size: 28)
            else
              SizedBox(
                width: 28,
                child: Icon(item.icon, size: 19, color: selected ? scheme.primary : scheme.onSurfaceVariant),
              ),
            const SizedBox(width: 12),
            Expanded(child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (item.hint != null)
              Text(item.hint!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }

  Widget _key(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
