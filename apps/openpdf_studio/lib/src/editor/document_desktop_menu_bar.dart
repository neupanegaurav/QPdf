import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'document_commands.dart';

class DocumentDesktopMenuBar extends StatelessWidget {
  const DocumentDesktopMenuBar({
    required this.canUndo,
    required this.canRedo,
    required this.canSave,
    required this.onOpen,
    required this.onSave,
    required this.onSaveAs,
    required this.onPrint,
    required this.onClose,
    required this.onUndo,
    required this.onRedo,
    required this.onFitPage,
    required this.onFitWidth,
    required this.onActualSize,
    required this.onVerticalLayout,
    required this.onHorizontalLayout,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onAllTools,
    required this.onCommand,
    super.key,
  });

  final bool canUndo;
  final bool canRedo;
  final bool canSave;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final VoidCallback onPrint;
  final VoidCallback onClose;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onFitPage;
  final VoidCallback onFitWidth;
  final VoidCallback onActualSize;
  final VoidCallback onVerticalLayout;
  final VoidCallback onHorizontalLayout;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onAllTools;
  final ValueChanged<DocumentCommandId> onCommand;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('document-desktop-menu-bar'),
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: MenuBar(
      style: const MenuStyle(
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
      ),
      children: [
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              key: const Key('desktop-menu-open'),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                meta: true,
              ),
              onPressed: onOpen,
              child: const Text('Open…'),
            ),
            MenuItemButton(
              key: const Key('desktop-menu-save'),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                meta: true,
              ),
              onPressed: canSave ? onSave : null,
              child: const Text('Save'),
            ),
            MenuItemButton(
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                meta: true,
                shift: true,
              ),
              onPressed: onSaveAs,
              child: const Text('Save As…'),
            ),
            MenuItemButton(
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyP,
                meta: true,
              ),
              onPressed: onPrint,
              child: const Text('Print…'),
            ),
            MenuItemButton(
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyW,
                meta: true,
              ),
              onPressed: onClose,
              child: const Text('Close tab'),
            ),
          ],
          child: const Text('File'),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              key: const Key('desktop-menu-undo'),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: true,
              ),
              onPressed: canUndo ? onUndo : null,
              child: const Text('Undo'),
            ),
            MenuItemButton(
              key: const Key('desktop-menu-redo'),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: true,
                shift: true,
              ),
              onPressed: canRedo ? onRedo : null,
              child: const Text('Redo'),
            ),
            MenuItemButton(
              onPressed: () => onCommand(DocumentCommandId.metadata),
              child: const Text('Document information…'),
            ),
          ],
          child: const Text('Edit'),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              key: const Key('desktop-menu-fit-page'),
              onPressed: onFitPage,
              child: const Text('Fit page'),
            ),
            MenuItemButton(
              key: const Key('desktop-menu-fit-width'),
              onPressed: onFitWidth,
              child: const Text('Fit width'),
            ),
            MenuItemButton(
              key: const Key('desktop-menu-actual-size'),
              onPressed: onActualSize,
              child: const Text('Actual size'),
            ),
            const Divider(),
            MenuItemButton(
              key: const Key('desktop-menu-vertical-layout'),
              onPressed: onVerticalLayout,
              child: const Text('Vertical continuous'),
            ),
            MenuItemButton(
              key: const Key('desktop-menu-horizontal-layout'),
              onPressed: onHorizontalLayout,
              child: const Text('Horizontal continuous'),
            ),
            const Divider(),
            MenuItemButton(
              onPressed: onRotateLeft,
              child: const Text('Rotate view left'),
            ),
            MenuItemButton(
              onPressed: onRotateRight,
              child: const Text('Rotate view right'),
            ),
          ],
          child: const Text('View'),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyK,
                meta: true,
              ),
              onPressed: onAllTools,
              child: const Text('All tools…'),
            ),
            for (final category in DocumentCommandCategory.values)
              SubmenuButton(
                menuChildren: [
                  for (final command in documentCommands.where(
                    (command) => command.category == category,
                  ))
                    MenuItemButton(
                      onPressed: () => onCommand(command.id),
                      leadingIcon: Icon(command.icon, size: 18),
                      child: Text(command.label),
                    ),
                ],
                child: Text(category.label),
              ),
          ],
          child: const Text('Tools'),
        ),
      ],
    ),
  );
}
