import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';

import 'document_commands.dart';

/// A desktop-first overview of QPdf's most useful editing workflows.
///
/// The layout deliberately groups outcomes instead of exposing the lower-level
/// editor toolbar vocabulary. This makes common PDF jobs easy to discover while
/// still handing control to the existing, fully featured editing surfaces.
class DocumentEditMenu extends StatelessWidget {
  const DocumentEditMenu({
    required this.onToolSelected,
    required this.onCommandSelected,
    required this.onFillAndSign,
    required this.onAllTools,
    super.key,
  });

  final ValueChanged<PdfEditTool> onToolSelected;
  final ValueChanged<DocumentCommandId> onCommandSelected;
  final VoidCallback onFillAndSign;
  final VoidCallback onAllTools;

  void _tool(BuildContext context, PdfEditTool tool) {
    Navigator.pop(context);
    onToolSelected(tool);
  }

  void _command(BuildContext context, DocumentCommandId command) {
    Navigator.pop(context);
    onCommandSelected(command);
  }

  void _action(BuildContext context, VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 980, maxHeight: 650),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.edit_document, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Edit PDF',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _action(context, onAllTools),
                    icon: const Icon(Icons.apps_outlined, size: 19),
                    label: const Text('All tools'),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _MenuSection(
                        title: 'Edit & annotate',
                        items: [
                          _MenuItem(
                            icon: Icons.text_fields,
                            title: 'Edit text & images',
                            description: 'Change existing page content',
                            onTap: () => _tool(context, PdfEditTool.content),
                          ),
                          _MenuItem(
                            icon: Icons.add_box_outlined,
                            title: 'Add text',
                            description: 'Place a new text box on a page',
                            onTap: () => _tool(context, PdfEditTool.freeText),
                          ),
                          _MenuItem(
                            icon: Icons.comment_outlined,
                            title: 'Add comments',
                            description: 'Add notes, highlights, and markup',
                            onTap: () => _tool(context, PdfEditTool.note),
                          ),
                          _MenuItem(
                            icon: Icons.check_box_outlined,
                            title: 'Prepare a form',
                            description: 'Add and edit interactive fields',
                            onTap: () => _tool(context, PdfEditTool.form),
                          ),
                          _MenuItem(
                            icon: Icons.draw_outlined,
                            title: 'Fill & Sign',
                            description:
                                'Fill fields, type, or add a signature',
                            onTap: () => _action(context, onFillAndSign),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 26),
                    Expanded(
                      child: _MenuSection(
                        title: 'Organize & enhance',
                        items: [
                          _MenuItem(
                            icon: Icons.document_scanner_outlined,
                            title: 'Recognize text (OCR)',
                            description: 'Make scanned pages searchable',
                            onTap: () =>
                                _command(context, DocumentCommandId.ocr),
                          ),
                          _MenuItem(
                            icon: Icons.compress_outlined,
                            title: 'Optimize PDF',
                            description: 'Reduce file size and image weight',
                            onTap: () =>
                                _command(context, DocumentCommandId.optimize),
                          ),
                          _MenuItem(
                            icon: Icons.format_list_numbered,
                            title: 'Number pages',
                            description: 'Add consistent page numbering',
                            onTap: () => _command(
                              context,
                              DocumentCommandId.pageNumbers,
                            ),
                          ),
                          _MenuItem(
                            icon: Icons.branding_watermark_outlined,
                            title: 'Add watermark',
                            description: 'Repeat visible text across pages',
                            onTap: () =>
                                _command(context, DocumentCommandId.watermark),
                          ),
                          _MenuItem(
                            icon: Icons.info_outline,
                            title: 'Document information',
                            description: 'Edit title, author, and keywords',
                            onTap: () =>
                                _command(context, DocumentCommandId.metadata),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 26),
                    Expanded(
                      child: _MenuSection(
                        title: 'Protect & verify',
                        items: [
                          _MenuItem(
                            icon: Icons.gradient,
                            title: 'Redact sensitive content',
                            description: 'Mark content for permanent removal',
                            onTap: () => _tool(context, PdfEditTool.redact),
                          ),
                          _MenuItem(
                            icon: Icons.shield_outlined,
                            title: 'Security & permissions',
                            description: 'Inspect encryption and restrictions',
                            onTap: () =>
                                _command(context, DocumentCommandId.security),
                          ),
                          _MenuItem(
                            icon: Icons.cleaning_services_outlined,
                            title: 'Remove hidden metadata',
                            description: 'Sanitize a copy before sharing',
                            onTap: () => _command(
                              context,
                              DocumentCommandId.scrubMetadata,
                            ),
                          ),
                          _MenuItem(
                            icon: Icons.verified_user_outlined,
                            title: 'Digitally sign',
                            description: 'Apply a cryptographic signature',
                            onTap: () => _command(
                              context,
                              DocumentCommandId.digitalSignature,
                            ),
                          ),
                          _MenuItem(
                            icon: Icons.verified_outlined,
                            title: 'Verify signatures',
                            description: 'Check document integrity and trust',
                            onTap: () => _command(
                              context,
                              DocumentCommandId.verifySignatures,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.items});

  final String title;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 7),
      const Divider(),
      const SizedBox(height: 4),
      ...items,
    ],
  );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 21, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
