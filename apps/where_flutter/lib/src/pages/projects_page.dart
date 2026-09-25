import 'package:flutter/material.dart';

import '../actions.dart';
import '../models.dart';
import '../state.dart';
import '../widgets.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context);
    final projects = state.list('project');
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          title: 'Projects',
          subtitle: projects.isEmpty
              ? 'Group related tasks, notes and folders together.'
              : '${projects.length} project${projects.length == 1 ? '' : 's'}',
          actions: [
            FilledButton.icon(
              onPressed: () => newObject(context, 'project'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New project'),
            ),
          ],
        ),
        Expanded(
          child: projects.isEmpty
              ? EmptyState(
                  icon: Icons.folder_special_outlined,
                  title: 'No projects yet',
                  message: 'A project collects everything about one piece of work — '
                      'its tasks, notes and folders — so you can find it all in one place.',
                  actionLabel: 'Create your first project',
                  onAction: () => newObject(context, 'project'),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(32, 4, 32, 32),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: 150,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: projects.length,
                  itemBuilder: (ctx, i) => FadeSlideIn(
                    key: ValueKey(projects[i].id),
                    index: i,
                    child: _ProjectCard(project: projects[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final WObject project;

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final children = state.detail(project.id)?.children ?? const <WObject>[];
    final tasks = children.where((c) => c.kind == 'task').toList();
    final done = tasks.where((c) => c.isDone).length;
    final notes = children.where((c) => c.kind == 'note').length;
    final other = children.length - tasks.length - notes;

    return HoverCard(
      onTap: () => openDetail(context, project.id),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const KindIcon('project'),
          const Spacer(),
          Text(timeAgo(project.updatedAt), style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: 12),
        Text(project.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          [
            '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
            '$notes note${notes == 1 ? '' : 's'}',
            if (other > 0) '$other other',
          ].join(' · '),
          style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const Spacer(),
        if (tasks.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: done / tasks.length),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 5,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
      ]),
    );
  }
}
