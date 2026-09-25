import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'pages/detail_page.dart';
import 'state.dart';
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
