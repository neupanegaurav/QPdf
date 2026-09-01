import 'package:flutter/material.dart';

enum DocumentWorkspaceMode {
  read('Read', Icons.menu_book_outlined),
  edit('Edit', Icons.edit_outlined),
  comment('Comment', Icons.comment_outlined),
  fillAndSign('Fill & Sign', Icons.draw_outlined),
  organize('Organize', Icons.view_module_outlined),
  convert('Convert', Icons.sync_alt_outlined),
  protect('Protect', Icons.shield_outlined);

  const DocumentWorkspaceMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

class DocumentModeRail extends StatelessWidget {
  const DocumentModeRail({
    required this.selected,
    required this.onSelected,
    required this.horizontal,
    super.key,
  });

  final DocumentWorkspaceMode selected;
  final ValueChanged<DocumentWorkspaceMode> onSelected;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    if (horizontal) {
      return Material(
        key: const Key('document-mode-bar'),
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 76,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              scrollDirection: Axis.horizontal,
              itemCount: DocumentWorkspaceMode.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final mode = DocumentWorkspaceMode.values[index];
                return _ModeButton(
                  mode: mode,
                  selected: mode == selected,
                  onTap: () => onSelected(mode),
                );
              },
            ),
          ),
        ),
      );
    }

    return Material(
      key: const Key('document-mode-rail'),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 92,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final mode in DocumentWorkspaceMode.values)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: _ModeButton(
                    mode: mode,
                    selected: mode == selected,
                    onTap: () => onSelected(mode),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final DocumentWorkspaceMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '${mode.label} workspace',
      child: InkWell(
        key: Key('document-mode-${mode.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minWidth: 76),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? colors.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mode.icon,
                size: 21,
                color: selected
                    ? colors.onSecondaryContainer
                    : colors.onSurfaceVariant,
              ),
              const SizedBox(height: 3),
              Text(
                mode.label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected
                      ? colors.onSecondaryContainer
                      : colors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
