import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/dms_entity.dart';

class DocumentPick {
  const DocumentPick({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
  });

  final String fileName;
  final Uint8List bytes;
  final String mimeType;

  String get title {
    final base = fileName.trim().split(RegExp(r'[\\/]')).last;
    final withoutExt = base.contains('.')
        ? base.substring(0, base.lastIndexOf('.'))
        : base;
    final cleaned = withoutExt.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    return cleaned.isEmpty ? base : cleaned;
  }

  String get category {
    final n = fileName.toLowerCase();
    if (n.contains('aadhar') ||
        n.contains('aadhaar') ||
        n.contains('passport') ||
        n.contains('marksheet') ||
        n.contains('degree') ||
        n.contains('graduat') ||
        n.contains('resume') ||
        n.contains('cv')) {
      return 'Identity';
    }
    if (n.contains('pan')) return 'Tax';
    if (n.contains('reliev') ||
        n.contains('offer') ||
        n.contains('contract') ||
        n.contains('agreement') ||
        n.contains('appointment') ||
        n.contains('msa') ||
        n.contains('nda')) {
      return 'Contracts';
    }
    if (n.contains('payslip') ||
        n.contains('salary') ||
        n.contains('payroll') ||
        n.contains('form16')) {
      return 'Payroll';
    }
    return DmsDocumentCategories.fallback;
  }
}

/// Simple multi-file browse zone for attaching documents.
class DocumentDropZone extends StatelessWidget {
  const DocumentDropZone({
    super.key,
    required this.onFilesPicked,
    this.enabled = true,
    this.uploading = false,
  });

  final ValueChanged<List<DocumentPick>> onFilesPicked;
  final bool enabled;
  final bool uploading;

  Future<void> _pick(BuildContext context) async {
    if (!enabled || uploading) return;
    final files = await FilePicker.pickFiles();
    if (files.isEmpty || !context.mounted) return;

    final picked = <DocumentPick>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      picked.add(
        DocumentPick(
          fileName: file.name,
          bytes: bytes,
          mimeType: _mimeFor(file.extension, file.name),
        ),
      );
    }
    if (picked.isEmpty || !context.mounted) return;
    onFilesPicked(picked);
  }

  static String _mimeFor(String? extension, String fileName) {
    final ext = (extension ?? '').toLowerCase();
    final name = fileName.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';
      default:
        if (name.endsWith('.pdf')) return 'application/pdf';
        if (name.endsWith('.png')) return 'image/png';
        if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
          return 'image/jpeg';
        }
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canTap = enabled && !uploading;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      child: InkWell(
        onTap: canTap ? () => _pick(context) : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: double.infinity,
          height: 140,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (uploading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.text,
                  ),
                )
              else
                const Icon(
                  Icons.upload_file_outlined,
                  size: 28,
                  color: AppColors.textLight,
                ),
              const SizedBox(height: 10),
              Text(
                uploading
                    ? 'Uploading…'
                    : 'Drop documents here or click to browse',
                textAlign: TextAlign.center,
                style: textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You can select multiple files at once',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
