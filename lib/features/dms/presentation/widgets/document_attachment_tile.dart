import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/dms_entity.dart';
import '../../domain/entities/document_record.dart';
import 'document_opener.dart';

class _CategoryStyle {
  const _CategoryStyle({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

_CategoryStyle categoryStyleFor(String category) {
  switch (category.trim().toLowerCase()) {
    case 'identity':
      return const _CategoryStyle(
        background: Color(0xFFE8F1FF),
        foreground: Color(0xFF1D4ED8),
      );
    case 'tax':
      return const _CategoryStyle(
        background: Color(0xFFFFF1E6),
        foreground: Color(0xFFC2410C),
      );
    case 'contracts':
      return const _CategoryStyle(
        background: Color(0xFFF3E8FF),
        foreground: Color(0xFF7E22CE),
      );
    case 'compliance':
      return const _CategoryStyle(
        background: Color(0xFFE6FFFA),
        foreground: Color(0xFF0F766E),
      );
    case 'payroll':
      return const _CategoryStyle(
        background: Color(0xFFE8F8EE),
        foreground: Color(0xFF15803D),
      );
    case 'general':
    default:
      return const _CategoryStyle(
        background: Color(0xFFF3F4F6),
        foreground: Color(0xFF4B5563),
      );
  }
}

/// Compact square attachment tile for a DMS document.
class DocumentAttachmentTile extends StatelessWidget {
  const DocumentAttachmentTile({
    super.key,
    required this.document,
    this.size = 104,
    this.showCategoryTag = true,
    this.onTap,
  });

  final DocumentRecord document;
  final double size;
  final bool showCategoryTag;
  final VoidCallback? onTap;

  static IconData iconFor(DocumentRecord document) => documentIconFor(document);

  String get _categoryLabel {
    final raw = document.category.trim();
    return raw.isEmpty ? 'General' : raw;
  }

  String get _displayTitle {
    final title = document.title.trim();
    if (title.isNotEmpty) return title;
    return document.fileName.trim();
  }

  String get _tooltipMessage {
    final title = _displayTitle;
    final fileName = document.fileName.trim();
    if (fileName.isNotEmpty &&
        fileName.toLowerCase() != title.toLowerCase()) {
      return '$title\n$fileName';
    }
    return title.isEmpty ? 'Document' : title;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = _displayTitle;
    final dateLabel = AppDates.dms.format(document.uploadedAt);
    final category = _categoryLabel;
    final tagStyle = categoryStyleFor(category);

    final tile = Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: size,
          height: size,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      iconFor(document),
                      size: 18,
                      color: AppColors.text,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                if (showCategoryTag)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tagStyle.background,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: tagStyle.foreground,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textLight,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Tooltip(
      message: _tooltipMessage,
      waitDuration: const Duration(milliseconds: 200),
      preferBelow: true,
      child: tile,
    );
  }
}

/// Continuous wrap of [DocumentAttachmentTile]s with category tags on each tile.
class DocumentAttachmentGrid extends StatelessWidget {
  const DocumentAttachmentGrid({
    super.key,
    required this.documents,
    this.tileSize = 104,
    this.spacing = 10,
  });

  final List<DocumentRecord> documents;
  final double tileSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final ordered = [...documents]..sort((a, b) {
          final ac = a.category.trim().isEmpty ? 'General' : a.category.trim();
          final bc = b.category.trim().isEmpty ? 'General' : b.category.trim();
          final ai = DmsDocumentCategories.all.indexOf(ac);
          final bi = DmsDocumentCategories.all.indexOf(bc);
          final ao = ai < 0 ? DmsDocumentCategories.all.length : ai;
          final bo = bi < 0 ? DmsDocumentCategories.all.length : bi;
          final byCategory = ao.compareTo(bo);
          if (byCategory != 0) return byCategory;
          final at = a.title.trim().isEmpty ? a.fileName : a.title;
          final bt = b.title.trim().isEmpty ? b.fileName : b.title;
          return at.toLowerCase().compareTo(bt.toLowerCase());
        });

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final doc in ordered)
          DocumentAttachmentTile(
            document: doc,
            size: tileSize,
            showCategoryTag: true,
            onTap: () => openDocumentRecord(context, doc),
          ),
      ],
    );
  }
}
