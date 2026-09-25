import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'pages/detail_page.dart';
import 'state.dart';
import 'where_core.dart';
import 'widgets.dart';

/// Opens an object's detail page with a soft fade + slide.
void openDetail(BuildContext context, String id) {
  final state = WhereScope.read(context);
  state.navigator.currentState?.push(detailRoute(id));
}

Route<void> detailRoute(String id) => PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => DetailPage(id: id),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.03, 0), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

/// Asks for a title, creates the object, and opens notes straight away.
Future<WObject?> newObject(BuildContext context, String kind, {WObject? project}) async {
  final state = WhereScope.read(context);
  final info = KindInfo.of(kind);
  final title = await promptText(
    context,
    title: project == null ? 'New ${info.singular.toLowerCase()}' : 'New ${info.singular.toLowerCase()} in ${project.title}',
    hint: _hint(kind),
  );
  if (title == null || title.trim().isEmpty) return null;
  final created = state.create(kind, title.trim(), projectId: project?.id);
  if (created != null && context.mounted && (kind == 'note' || kind == 'project')) {
    openDetail(context, created.id);
  }
  return created;
}

String _hint(String kind) {
  switch (kind) {
    case 'project':
      return 'e.g. Website redesign';
    case 'task':
      return 'e.g. Fix login bug';
    case 'note':
      return 'e.g. Meeting notes';
    default:
      return '';
  }
}

Future<void> pickAndIndexFolder(BuildContext context) async {
  final state = WhereScope.read(context);
  final path = await getDirectoryPath(confirmButtonText: 'Index this folder');
  if (path == null) return;
  await state.indexFolder(path);
}

Future<void> pickAndExport(BuildContext context, String format) async {
  final state = WhereScope.read(context);
  final dir = await getDirectoryPath(confirmButtonText: 'Export here');
  if (dir == null) return;
  state.export(format, dir);
}

/// Opens a file with its default app, or shows it in the file manager.
Future<void> openPath(BuildContext context, String path, {bool reveal = false}) async {
  final state = WhereScope.read(context);
  try {
    if (!File(path).existsSync() && !Directory(path).existsSync()) {
      state.toast('That file is no longer at $path. Refresh the folder to update Where.', error: true);
      return;
    }
    if (Platform.isWindows) {
      await Process.start('explorer.exe', reveal ? ['/select,', path] : [path]);
    } else if (Platform.isMacOS) {
      await Process.start('open', reveal ? ['-R', path] : [path]);
    } else {
      await Process.start('xdg-open', [reveal ? File(path).parent.path : path]);
    }
  } catch (e) {
    state.toast('Could not open $path', error: true);
  }
}

/// Opens a saved web link in the default browser.
Future<void> openUrl(BuildContext context, String url) async {
  final state = WhereScope.read(context);
  if (!LinkInfo.isWebUrl(url)) {
    state.toast('That isn’t a web address Where can open.', error: true);
    return;
  }
  final ok = await launchUrl(Uri.parse(url.trim()), mode: LaunchMode.externalApplication);
  if (!ok) state.toast('Couldn’t open $url', error: true);
}

Future<void> copyText(BuildContext context, String text, {String what = 'Link'}) async {
  final state = WhereScope.read(context);
  await Clipboard.setData(ClipboardData(text: text));
  state.toast('$what copied');
}

/// Dialog for adding (or editing) a web link by hand.
Future<WObject?> showAddLinkDialog(BuildContext context, {WObject? project, String initialUrl = ''}) {
  final state = WhereScope.read(context);
  final url = TextEditingController(text: initialUrl);
  final title = TextEditingController();
  final note = TextEditingController();
  final projects = state.list('project');
  String? projectId = project?.id;
  String? error;

  return showDialog<WObject>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        void save() {
          final u = url.text.trim();
          final withScheme = u.contains('://') ? u : 'https://$u';
          if (!LinkInfo.isWebUrl(withScheme)) {
            setLocal(() => error = 'Enter a web address, like example.com or https://example.com/page');
            return;
          }
          try {
            final link = state.saveLink(
              url: withScheme,
              title: title.text,
              note: note.text,
              projectId: projectId,
            );
            state.toast('Link saved');
            Navigator.pop(ctx, link);
          } on WhereException catch (e) {
            setLocal(() => error = e.message);
          }
        }

        return AlertDialog(
          title: const Text('Add a link'),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: url,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Web address',
                  hintText: 'https://example.com/page',
                  prefixIcon: const Icon(Icons.link_rounded),
                  errorText: error,
                ),
                onChanged: (_) {
                  if (error != null) setLocal(() => error = null);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Leave empty to use the site name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Why is this worth keeping?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: projectId,
                decoration: const InputDecoration(labelText: 'Project'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('No project')),
                  for (final p in projects) DropdownMenuItem<String?>(value: p.id, child: Text(p.title)),
                ],
                onChanged: (v) => setLocal(() => projectId = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('Save link'),
            ),
          ],
        );
      },
    ),
  );
}
