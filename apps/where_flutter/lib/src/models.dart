import 'package:flutter/material.dart';

/// An object in Where (project, task, note, file, …).
class WObject {
  const WObject({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.properties,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WObject.fromJson(Map<String, dynamic> j) => WObject(
        id: j['id'] as String,
        kind: j['kind'] as String,
        title: j['title'] as String,
        body: (j['body'] as String?) ?? '',
        properties: (j['properties'] as Map<String, dynamic>?) ?? const {},
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
      );

  final String id;
  final String kind;
  final String title;
  final String body;
  final Map<String, dynamic> properties;
  final DateTime createdAt;
  final DateTime updatedAt;

  String? prop(String key) {
    final v = properties[key];
    return v is String ? v : null;
  }

  int? intProp(String key) {
    final v = properties[key];
    return v is int ? v : null;
  }

  String get status => prop('status') ?? 'todo';
  bool get isDone => status == 'done';
  KindInfo get info => KindInfo.of(kind);
}

class Related {
  const Related({required this.relation, required this.outgoing, required this.object});

  factory Related.fromJson(Map<String, dynamic> j) => Related(
        relation: j['kind'] as String,
        outgoing: j['direction'] == 'outgoing',
        object: WObject.fromJson(j['object'] as Map<String, dynamic>),
      );

  final String relation;
  final bool outgoing;
  final WObject object;

  String get label {
    if (outgoing) return relation;
    switch (relation) {
      case 'contains':
        return 'part of';
      case 'involves':
        return 'involved in';
      default:
        return 'referenced by';
    }
  }
}

class Detail {
  const Detail(this.object, this.related);

  factory Detail.fromJson(Map<String, dynamic> j) => Detail(
        WObject.fromJson(j['object'] as Map<String, dynamic>),
        (j['related'] as List<dynamic>)
            .map((r) => Related.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  final WObject object;
  final List<Related> related;

  List<WObject> get parents =>
      related.where((r) => !r.outgoing && r.relation == 'contains').map((r) => r.object).toList();
  List<WObject> get children =>
      related.where((r) => r.outgoing && r.relation == 'contains').map((r) => r.object).toList();
}

class Hit {
  const Hit({required this.object, required this.viaContainer, required this.via});

  factory Hit.fromJson(Map<String, dynamic> j) => Hit(
        object: WObject.fromJson(j['object'] as Map<String, dynamic>),
        viaContainer: j['reason'] == 'contains',
        via: ((j['via'] as List<dynamic>?) ?? const []).map((v) => v.toString()).toList(),
      );

  final WObject object;
  final bool viaContainer;
  final List<String> via;
}

/// Display metadata for each object kind.
class KindInfo {
  const KindInfo(this.kind, this.singular, this.plural, this.icon, this.swatch, this.rank);

  final String kind;
  final String singular;
  final String plural;
  final IconData icon;
  final MaterialColor swatch;
  final int rank;

  Color color(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? swatch.shade300 : swatch.shade700;

  Color tint(BuildContext context) => Theme.of(context).brightness == Brightness.dark
      ? swatch.shade300.withAlpha(38)
      : swatch.shade100.withAlpha(160);

  static const _all = <KindInfo>[
    KindInfo('project', 'Project', 'Projects', Icons.folder_special_outlined, Colors.indigo, 0),
    KindInfo('task', 'Task', 'Tasks', Icons.check_circle_outline, Colors.teal, 1),
    KindInfo('note', 'Note', 'Notes', Icons.sticky_note_2_outlined, Colors.amber, 2),
    KindInfo('file', 'File', 'Files', Icons.insert_drive_file_outlined, Colors.blueGrey, 3),
    KindInfo('folder', 'Folder', 'Folders', Icons.folder_outlined, Colors.brown, 4),
    KindInfo('person', 'Person', 'People', Icons.person_outline, Colors.cyan, 5),
    KindInfo('website', 'Website', 'Websites', Icons.language, Colors.lightBlue, 6),
    KindInfo('bookmark', 'Bookmark', 'Bookmarks', Icons.bookmark_outline, Colors.orange, 7),
    KindInfo('image', 'Image', 'Images', Icons.image_outlined, Colors.pink, 8),
    KindInfo('video', 'Video', 'Videos', Icons.movie_outlined, Colors.deepPurple, 9),
    KindInfo('repository', 'Repository', 'Repositories', Icons.code, Colors.green, 10),
    KindInfo('application', 'App', 'Apps', Icons.apps, Colors.purple, 11),
    KindInfo('conversation', 'Conversation', 'Conversations', Icons.forum_outlined, Colors.lime, 12),
    KindInfo('calendar_event', 'Event', 'Events', Icons.event_outlined, Colors.red, 13),
    KindInfo('device', 'Device', 'Devices', Icons.devices_other, Colors.grey, 14),
    KindInfo('organization', 'Organization', 'Organizations', Icons.apartment, Colors.deepOrange, 15),
  ];

  static KindInfo of(String kind) =>
      _all.firstWhere((k) => k.kind == kind, orElse: () => _all[3]);
}

const taskStatuses = ['todo', 'in_progress', 'done'];

String statusLabel(String s) {
  switch (s) {
    case 'in_progress':
      return 'In progress';
    case 'done':
      return 'Done';
    default:
      return 'To do';
  }
}

String formatBytes(int? bytes) {
  if (bytes == null) return '';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return unit == 0 ? '$bytes B' : '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${units[unit]}';
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t.toLocal());
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays == 1) return 'yesterday';
  if (d.inDays < 7) return '${d.inDays} days ago';
  final l = t.toLocal();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[l.month - 1]} ${l.day}, ${l.year}';
}
