import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'command_palette.dart';
import 'pages/files_page.dart';
import 'pages/home_page.dart';
import 'pages/links_page.dart';
import 'pages/notes_page.dart';
import 'pages/projects_page.dart';
import 'pages/settings_page.dart';
import 'pages/tasks_page.dart';
import 'state.dart';
import 'theme.dart';

/// Sidebar + content area. Detail pages open inside the content area so the
/// sidebar stays put.
class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => showCommandPalette(context),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => showCommandPalette(context),
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => state.go(Section.home),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => state.go(Section.projects),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => state.go(Section.tasks),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => state.go(Section.notes),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true): () => state.go(Section.links),
        const SingleActivator(LogicalKeyboardKey.digit6, control: true): () => state.go(Section.files),
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () => state.go(Section.settings),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(children: [
            const _Sidebar(),
            Expanded(
              child: ClipRect(
                child: Navigator(
                  key: state.navigator,
                  onGenerateRoute: (_) => PageRouteBuilder<void>(
                    pageBuilder: (_, __, ___) => const _SectionHost(),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SectionHost extends StatelessWidget {
  const _SectionHost();

  @override
  Widget build(BuildContext context) {
    final section = WhereScope.of(context).section;
    return AnimatedSwitcher(
      duration: WhereTheme.medium,
      switchInCurve: WhereTheme.curve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(section), child: _page(section)),
    );
  }

  Widget _page(Section s) {
    switch (s) {
      case Section.home:
        return const HomePage();
      case Section.projects:
        return const ProjectsPage();
      case Section.tasks:
        return const TasksPage();
      case Section.notes:
        return const NotesPage();
      case Section.links:
        return const LinksPage();
      case Section.files:
        return const FilesPage();
      case Section.settings:
        return const SettingsPage();
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(right: BorderSide(color: scheme.outlineVariant.withAlpha(90))),
      ),
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.travel_explore, size: 18, color: scheme.onPrimary),
            ),
            const SizedBox(width: 10),
            Text('Where', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ]),
        ),
        const SizedBox(height: 18),
        _PaletteButton(onTap: () => showCommandPalette(context)),
        const SizedBox(height: 14),
        for (final s in Section.values.where((s) => s != Section.settings))
          _NavItem(section: s, selected: state.section == s, onTap: () => state.go(s)),
        const Spacer(),
        AnimatedSwitcher(
          duration: WhereTheme.medium,
          child: state.indexing
              ? Padding(
                  key: const ValueKey('indexing'),
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Indexing…', style: t.labelMedium),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(minHeight: 4),
                    ),
                  ]),
                )
              : const SizedBox(key: ValueKey('idle')),
        ),
        _NavItem(
          section: Section.settings,
          selected: state.section == Section.settings,
          onTap: () => state.go(Section.settings),
        ),
        const SizedBox(height: 4),
        Row(children: [
          const SizedBox(width: 8),
          Icon(Icons.lock_outline, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Stored on this device',
                style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          IconButton(
            tooltip: 'Theme: ${state.themeMode.name}',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: state.cycleTheme,
            icon: AnimatedSwitcher(
              duration: WhereTheme.medium,
              transitionBuilder: (c, a) => RotationTransition(
                turns: Tween(begin: 0.75, end: 1.0).animate(a),
                child: FadeTransition(opacity: a, child: c),
              ),
              child: Icon(
                const {
                  ThemeMode.system: Icons.brightness_auto_outlined,
                  ThemeMode.light: Icons.light_mode_outlined,
                  ThemeMode.dark: Icons.dark_mode_outlined,
                }[state.themeMode],
                key: ValueKey(state.themeMode),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.section, required this.selected, required this.onTap});

  final Section section;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sel = widget.selected;
    final fg = sel ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: WhereTheme.fast,
            curve: WhereTheme.curve,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: sel
                  ? scheme.secondaryContainer
                  : _hover
                      ? scheme.onSurface.withAlpha(12)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              AnimatedScale(
                scale: sel ? 1.08 : 1,
                duration: WhereTheme.medium,
                curve: Curves.easeOutBack,
                child: Icon(sel ? widget.section.selectedIcon : widget.section.icon, size: 20, color: fg),
              ),
              const SizedBox(width: 12),
              Text(
                widget.section.label,
                style: TextStyle(color: fg, fontWeight: sel ? FontWeight.w700 : FontWeight.w500),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PaletteButton extends StatefulWidget {
  const _PaletteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PaletteButton> createState() => _PaletteButtonState();
}

class _PaletteButtonState extends State<_PaletteButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: WhereTheme.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _hover ? scheme.surfaceContainerHigh : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant.withAlpha(_hover ? 180 : 100)),
          ),
          child: Row(children: [
            Icon(Icons.bolt_rounded, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('Quick actions', style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text('Ctrl K', style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ]),
        ),
      ),
    );
  }
}
