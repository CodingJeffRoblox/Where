import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

/// Fades and slides its child in once, optionally after a short delay.
/// Used for list items (with [index] for a gentle stagger) and page content.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 14,
    this.duration = WhereTheme.slow,
  });

  final Widget child;
  final int index;
  final double offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    // Cap the stagger so long lists don't feel slow.
    final delay = (index < 0 ? 0 : (index > 12 ? 12 : index)) * 28;
    final total = duration + Duration(milliseconds: delay);
    final start = delay / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: WhereTheme.curve),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * offset), child: child),
      ),
      child: child,
    );
  }
}

/// A card that lifts slightly and highlights on hover.
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.selected = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool selected;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _hover || widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: WhereTheme.fast,
        curve: WhereTheme.curve,
        transform: Matrix4.translationValues(0, active ? -1.5 : 0, 0),
        decoration: BoxDecoration(
          color: active ? scheme.surfaceContainer : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(WhereTheme.radius),
          border: Border.all(
            color: widget.selected
                ? scheme.primary.withAlpha(150)
                : scheme.outlineVariant.withAlpha(active ? 160 : 90),
          ),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 16, offset: const Offset(0, 6))]
              : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(WhereTheme.radius),
            onTap: widget.onTap,
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Coloured rounded icon for an object kind.
class KindIcon extends StatelessWidget {
  const KindIcon(this.kind, {super.key, this.size = 36});

  final String kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final info = KindInfo.of(kind);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: info.tint(context),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(info.icon, size: size * 0.52, color: info.color(context)),
    );
  }
}

/// Small pill label.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.icon});

  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.withAlpha(28),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 4)],
        Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c)),
      ]),
    );
  }
}

Color statusColor(BuildContext context, String status) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  switch (status) {
    case 'done':
      return dark ? Colors.green.shade300 : Colors.green.shade700;
    case 'in_progress':
      return dark ? Colors.amber.shade300 : Colors.orange.shade800;
    default:
      return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

/// Round checkbox that animates between states.
class TaskCheck extends StatelessWidget {
  const TaskCheck({super.key, required this.status, required this.onChanged});

  final String status;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final done = status == 'done';
    final c = statusColor(context, done ? 'done' : status);
    return Tooltip(
      message: done ? 'Mark as not done' : 'Mark as done',
      child: InkResponse(
        radius: 18,
        onTap: () => onChanged(done ? 'todo' : 'done'),
        child: AnimatedContainer(
          duration: WhereTheme.medium,
          curve: Curves.easeOutBack,
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? c : Colors.transparent,
            border: Border.all(color: c, width: 2),
          ),
          child: AnimatedSwitcher(
            duration: WhereTheme.fast,
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: done
                ? const Icon(Icons.check, key: ValueKey('on'), size: 14, color: Colors.white)
                : status == 'in_progress'
                    ? Container(
                        key: const ValueKey('mid'),
                        margin: const EdgeInsets.all(5),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: c),
                      )
                    : const SizedBox(key: ValueKey('off')),
          ),
        ),
      ),
    );
  }
}

/// Friendly empty state with an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: FadeSlideIn(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(24),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 30, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: t.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message,
                style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Page header used by every section.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ]),
        ),
        ...actions.expand((a) => [const SizedBox(width: 8), a]),
      ]),
    );
  }
}

/// Asks for a single line of text (used for "New task", "Rename", …).
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String hint = '',
  String initial = '',
  String action = 'Create',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(action)),
      ],
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Remove',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(width: 380, child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}
