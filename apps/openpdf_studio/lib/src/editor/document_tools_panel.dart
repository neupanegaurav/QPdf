import 'package:flutter/material.dart';

import 'document_commands.dart';

class DocumentToolsPanel extends StatefulWidget {
  const DocumentToolsPanel({required this.onSelected, super.key});

  final ValueChanged<DocumentCommandId> onSelected;

  @override
  State<DocumentToolsPanel> createState() => _DocumentToolsPanelState();
}

class _DocumentToolsPanelState extends State<DocumentToolsPanel> {
  String _query = '';
  DocumentCommandCategory? _category;

  @override
  Widget build(BuildContext context) {
    final commands = documentCommands
        .where((command) => _category == null || command.category == _category)
        .where((command) => command.matches(_query))
        .toList(growable: false);
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'All tools',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SearchBar(
                key: const Key('document-tools-search'),
                hintText: 'Search document tools',
                leading: const Icon(Icons.search),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                    for (final category in DocumentCommandCategory.values) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(category.label),
                        selected: _category == category,
                        onSelected: (_) =>
                            setState(() => _category = category),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: commands.isEmpty
                    ? const Center(child: Text('No matching tools'))
                    : ListView.builder(
                        itemCount: commands.length,
                        itemBuilder: (context, index) {
                          final command = commands[index];
                          return ListTile(
                            leading: Icon(command.icon),
                            title: Text(command.label),
                            subtitle: Text(command.description),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelected(command.id);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

