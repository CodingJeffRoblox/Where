import 'package:flutter/material.dart';

import '../actions.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String _filter = 'open';

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context);
    final all = state.list('task');
    final open = all.where((t) => !t.isDone).length;
    final shown = all.where((t) {
      switch (_filter) {
        case 'open':
          return !t.isDone;
        case 'all':
          return true;
        default:
          return t.status == _filter;
      }
    }).toList()
      ..sort((a, b) {
        // In progress first, then to do, then done; newest first within each.
        const order = {'in_progress': 0, 'todo': 1, 'done': 2};
        final c = (order[a.status] ?? 1).compareTo(order[b.status] ?? 1);
        return c != 0 ? c : b.updatedAt.compareTo(a.updatedAt);
      });

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          title: 'Tasks',
          subtitle: all.isEmpty ? 'Things to do, connected to the work they belong to.' : '$open open · ${all.length - open} done',
          actions: [
            FilledButton.icon(
              onPressed: () => newObject(context, 'task'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New task'),
            ),
          ],
        ),
        if (all.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'open', label: Text('Open')),
                  ButtonSegment(value: 'in_progress', label: Text('In progress')),
                  ButtonSegment(value: 'done', label: Text('Done')),
                  ButtonSegment(value: 'all', label: Text('All')),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
          ),
        Expanded(
          child: all.isEmpty
              ? EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No tasks yet',
                  message: 'Add a task and put it in a project — Where will show it '
                      'whenever you search for that project.',
                  actionLabel: 'Add a task',
                  onAction: () => newObject(context, 'task'),
                )
              : shown.isEmpty
                  ? EmptyState(
                      icon: Icons.celebration_outlined,
                      title: _filter == 'done' ? 'Nothing finished yet' : 'All clear',
                      message: _filter == 'done' ? 'Completed tasks will show up here.' : 'No tasks match this filter.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                      itemCount: shown.length,
                      itemBuilder: (ctx, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: FadeSlideIn(
                          key: ValueKey('${shown[i].id}-$_filter'),
                          index: i,
                          child: TaskRow(task: shown[i]),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}

/// A task with a checkbox, animated strike-through, project and status.
class TaskRow extends StatelessWidget {
  const TaskRow({super.key, required this.task, this.showProject = true});

  final WObject task;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final projects = showProject
        ? (state.detail(task.id)?.parents ?? const <WObject>[]).where((p) => p.kind == 'project').toList()
        : const <WObject>[];
    final project = projects.isEmpty ? null : projects.first;
    return HoverCard(
      onTap: () => openDetail(context, task.id),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(children: [
        TaskCheck(status: task.status, onChanged: (s) => state.setStatus(task, s)),
        const SizedBox(width: 14),
        Expanded(
          child: AnimatedDefaultTextStyle(
            duration: WhereTheme.medium,
            style: t.bodyLarge!.copyWith(
              color: task.isDone ? scheme.onSurfaceVariant : scheme.onSurface,
              decoration: task.isDone ? TextDecoration.lineThrough : TextDecoration.none,
              decorationColor: scheme.onSurfaceVariant,
            ),
            child: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        if (project != null) ...[
          const SizedBox(width: 10),
          Pill(project.title, icon: Icons.folder_special_outlined, color: project.info.color(context)),
        ],
        if (task.status == 'in_progress') ...[
          const SizedBox(width: 8),
          Pill('In progress', color: statusColor(context, 'in_progress')),
        ],
        const SizedBox(width: 10),
        Text(timeAgo(task.updatedAt), style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}
