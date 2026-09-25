import 'package:flutter/material.dart';

import '../actions.dart';
import '../models.dart';
import '../state.dart';
import '../widgets.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = WhereScope.of(context);
    final notes = state.list('note');
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          title: 'Notes',
          subtitle: notes.isEmpty ? 'Write things down and link them to your work.' : '${notes.length} note${notes.length == 1 ? '' : 's'}',
          actions: [
            FilledButton.icon(
              onPressed: () => newObject(context, 'note'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New note'),
            ),
          ],
        ),
        Expanded(
          child: notes.isEmpty
              ? EmptyState(
                  icon: Icons.sticky_note_2_outlined,
                  title: 'No notes yet',
                  message: 'Notes are searchable along with everything else, '
                      'and can belong to a project.',
                  actionLabel: 'Write a note',
                  onAction: () => newObject(context, 'note'),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(32, 4, 32, 32),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    mainAxisExtent: 170,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: notes.length,
                  itemBuilder: (ctx, i) {
                    final n = notes[i];
                    return FadeSlideIn(
                      key: ValueKey(n.id),
                      index: i,
                      child: HoverCard(
                        onTap: () => openDetail(context, n.id),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const KindIcon('note', size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(n.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Text(
                              n.body.isEmpty ? 'Empty note' : n.body,
                              maxLines: 4,
                              overflow: TextOverflow.fade,
                              style: t.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontStyle: n.body.isEmpty ? FontStyle.italic : FontStyle.normal,
                                height: 1.4,
                              ),
                            ),
                          ),
                          Text(timeAgo(n.updatedAt),
                              style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
