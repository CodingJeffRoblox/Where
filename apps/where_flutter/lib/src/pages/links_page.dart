import 'package:flutter/material.dart';

import '../actions.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class LinksPage extends StatefulWidget {
  const LinksPage({super.key});

  @override
  State<LinksPage> createState() => _LinksPageState();
}

class _LinksPageState extends State<LinksPage> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context);
    final links = state.list('bookmark');
    final q = _filter.trim().toLowerCase();
    final shown = q.isEmpty
        ? links
        : links
            .where((l) => '${l.title} ${l.prop('url') ?? ''} ${l.body}'.toLowerCase().contains(q))
            .toList();

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          title: 'Links',
          subtitle: links.isEmpty
              ? 'Websites worth keeping, with your notes.'
              : '${links.length} saved link${links.length == 1 ? '' : 's'}',
          actions: [
            OutlinedButton.icon(
              onPressed: () => state.go(Section.settings),
              icon: const Icon(Icons.extension_outlined, size: 18),
              label: Text(state.browserClients.isEmpty ? 'Connect a browser' : 'Browser connected'),
            ),
            FilledButton.icon(
              onPressed: () => showAddLinkDialog(context),
              icon: const Icon(Icons.add_link, size: 18),
              label: const Text('Add link'),
            ),
          ],
        ),
        if (links.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
            child: TextField(
              onChanged: (v) => setState(() => _filter = v),
              decoration: const InputDecoration(
                hintText: 'Filter by title, address or note…',
                prefixIcon: Icon(Icons.filter_list_rounded),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        Expanded(
          child: links.isEmpty
              ? EmptyState(
                  icon: Icons.link_rounded,
                  title: 'No links yet',
                  message: 'Save a page from your browser with the Where extension '
                      '(Settings → Browser), or add one here. Add a note so you '
                      'remember why it matters.',
                  actionLabel: 'Add a link',
                  onAction: () => showAddLinkDialog(context),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  itemCount: shown.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FadeSlideIn(
                      key: ValueKey(shown[i].id),
                      index: i,
                      child: LinkRow(link: shown[i]),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }
}

/// A saved link: site avatar, title, clickable address, note and project.
class LinkRow extends StatelessWidget {
  const LinkRow({super.key, required this.link, this.showProject = true});

  final WObject link;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final url = link.prop('url') ?? '';
    final projects = showProject
        ? (state.detail(link.id)?.parents ?? const <WObject>[]).where((p) => p.kind == 'project').toList()
        : const <WObject>[];

    return HoverCard(
      onTap: () => openDetail(context, link.id),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SiteAvatar(url: url),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(link.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            UrlText(url: url, style: t.bodySmall),
            if (link.body.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                link.body.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
              ),
            ],
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (projects.isNotEmpty)
                Pill(projects.first.title,
                    icon: Icons.folder_special_outlined, color: projects.first.info.color(context)),
              Text(timeAgo(link.updatedAt), style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ]),
        ),
        IconButton(
          tooltip: 'Copy link',
          icon: const Icon(Icons.content_copy_rounded, size: 18),
          onPressed: url.isEmpty ? null : () => copyText(context, url),
        ),
        IconButton(
          tooltip: 'Open in browser',
          icon: const Icon(Icons.open_in_new_rounded, size: 20),
          onPressed: url.isEmpty ? null : () => openUrl(context, url),
        ),
      ]),
    );
  }
}

/// Coloured letter avatar for a site. No favicons are fetched, so nothing
/// about your saved links is sent to the internet.
class SiteAvatar extends StatelessWidget {
  const SiteAvatar({super.key, required this.url, this.size = 38});

  final String url;
  final double size;

  static const _swatches = [
    Colors.indigo, Colors.teal, Colors.orange, Colors.pink, Colors.blue,
    Colors.green, Colors.deepPurple, Colors.cyan, Colors.red, Colors.brown,
  ];

  @override
  Widget build(BuildContext context) {
    final domain = LinkInfo.domain(url);
    final letter = domain.isEmpty ? '?' : domain[0].toUpperCase();
    final swatch = _swatches[domain.codeUnits.fold<int>(0, (a, b) => a + b) % _swatches.length];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? swatch.shade300.withAlpha(45) : swatch.shade100,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w800,
          color: dark ? swatch.shade200 : swatch.shade800,
        ),
      ),
    );
  }
}

/// A web address that opens in the browser when clicked.
class UrlText extends StatefulWidget {
  const UrlText({super.key, required this.url, this.style, this.maxLines = 1});

  final String url;
  final TextStyle? style;
  final int maxLines;

  @override
  State<UrlText> createState() => _UrlTextState();
}

class _UrlTextState extends State<UrlText> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final display = widget.url.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => openUrl(context, widget.url),
        child: Tooltip(
          message: 'Open ${widget.url}',
          child: AnimatedDefaultTextStyle(
            duration: WhereTheme.fast,
            style: (widget.style ?? const TextStyle()).copyWith(
              color: scheme.primary,
              decoration: _hover ? TextDecoration.underline : TextDecoration.none,
              decorationColor: scheme.primary,
            ),
            child: Text(display, maxLines: widget.maxLines, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}
