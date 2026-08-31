import 'package:flutter/material.dart';

enum DocumentCommandCategory {
  output('Output'),
  enhance('Enhance'),
  organize('Organize'),
  protect('Protect'),
  sign('Sign'),
  inspect('Inspect');

  const DocumentCommandCategory(this.label);

  final String label;
}

enum DocumentCommandId {
  print,
  share,
  ocr,
  pageNumbers,
  watermark,
  bates,
  metadata,
  compare,
  audit,
  security,
  optimize,
  scrubMetadata,
  pdfa,
  digitalSignature,
  verifySignatures,
}

@immutable
final class DocumentCommand {
  const DocumentCommand({
    required this.id,
    required this.label,
    required this.description,
    required this.category,
    required this.icon,
    this.searchTerms = const [],
  });

  final DocumentCommandId id;
  final String label;
  final String description;
  final DocumentCommandCategory category;
  final IconData icon;
  final List<String> searchTerms;

  bool matches(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    return <String>[
      label,
      description,
      category.label,
      ...searchTerms,
    ].any((value) => value.toLowerCase().contains(query));
  }
}

const documentCommands = <DocumentCommand>[
  DocumentCommand(
    id: DocumentCommandId.print,
    label: 'Print',
    description: 'Print the current PDF.',
    category: DocumentCommandCategory.output,
    icon: Icons.print_outlined,
  ),
  DocumentCommand(
    id: DocumentCommandId.share,
    label: 'Share PDF',
    description: 'Send a copy using the system share sheet.',
    category: DocumentCommandCategory.output,
    icon: Icons.share_outlined,
  ),
  DocumentCommand(
    id: DocumentCommandId.pdfa,
    label: 'Convert to PDF/A',
    description: 'Create a standards-oriented archival copy.',
    category: DocumentCommandCategory.output,
    icon: Icons.inventory_2_outlined,
    searchTerms: ['archive', 'compliance'],
  ),
  DocumentCommand(
    id: DocumentCommandId.ocr,
    label: 'Make text searchable (OCR)',
    description: 'Recognize text in scanned pages on this device.',
    category: DocumentCommandCategory.enhance,
    icon: Icons.document_scanner_outlined,
    searchTerms: ['scan', 'recognize'],
  ),
  DocumentCommand(
    id: DocumentCommandId.optimize,
    label: 'Optimize PDF',
    description: 'Reduce file size with adjustable image quality.',
    category: DocumentCommandCategory.enhance,
    icon: Icons.compress_outlined,
    searchTerms: ['compress', 'size'],
  ),
  DocumentCommand(
    id: DocumentCommandId.pageNumbers,
    label: 'Add page numbers',
    description: 'Number every page using a repeatable layout.',
    category: DocumentCommandCategory.organize,
    icon: Icons.format_list_numbered,
  ),
  DocumentCommand(
    id: DocumentCommandId.watermark,
    label: 'Add watermark',
    description: 'Repeat visible text across document pages.',
    category: DocumentCommandCategory.organize,
    icon: Icons.branding_watermark_outlined,
  ),
  DocumentCommand(
    id: DocumentCommandId.bates,
    label: 'Add Bates numbers',
    description: 'Apply legal-document sequence numbering.',
    category: DocumentCommandCategory.organize,
    icon: Icons.numbers_outlined,
    searchTerms: ['legal'],
  ),
  DocumentCommand(
    id: DocumentCommandId.security,
    label: 'Security & permissions',
    description: 'Inspect encryption and allowed operations.',
    category: DocumentCommandCategory.protect,
    icon: Icons.shield_outlined,
  ),
  DocumentCommand(
    id: DocumentCommandId.scrubMetadata,
    label: 'Remove hidden metadata',
    description: 'Sanitize metadata before sharing a copy.',
    category: DocumentCommandCategory.protect,
    icon: Icons.cleaning_services_outlined,
    searchTerms: ['privacy', 'sanitize'],
  ),
  DocumentCommand(
    id: DocumentCommandId.digitalSignature,
    label: 'Add digital signature',
    description: 'Apply a local cryptographic signature.',
    category: DocumentCommandCategory.sign,
    icon: Icons.verified_user_outlined,
    searchTerms: ['certificate'],
  ),
  DocumentCommand(
    id: DocumentCommandId.verifySignatures,
    label: 'Verify signatures',
    description: 'Inspect integrity and trust information.',
    category: DocumentCommandCategory.sign,
    icon: Icons.verified_outlined,
    searchTerms: ['certificate', 'validate'],
  ),
  DocumentCommand(
    id: DocumentCommandId.metadata,
    label: 'Document information',
    description: 'View and edit title, author, and keywords.',
    category: DocumentCommandCategory.inspect,
    icon: Icons.info_outline,
    searchTerms: ['metadata', 'properties'],
  ),
  DocumentCommand(
    id: DocumentCommandId.compare,
    label: 'Compare with PDF',
    description: 'Report text and page-structure differences.',
    category: DocumentCommandCategory.inspect,
    icon: Icons.compare_outlined,
    searchTerms: ['difference', 'diff'],
  ),
  DocumentCommand(
    id: DocumentCommandId.audit,
    label: 'Standards audit',
    description: 'Check PDF/A and PDF/UA document structure.',
    category: DocumentCommandCategory.inspect,
    icon: Icons.fact_check_outlined,
    searchTerms: ['accessibility', 'compliance'],
  ),
];

