import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';
import '../widgets/cafe_pos_chrome.dart';

/// Print / share QR codes for the guest menu (`/m/:cafeId` ± table).
class CafeQrPrintPage extends StatefulWidget {
  const CafeQrPrintPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafeQrPrintPage> createState() => _CafeQrPrintPageState();
}

class _CafeQrPrintPageState extends State<CafeQrPrintPage> {
  Cafe? _cafe;
  bool _loading = true;
  String? _error;
  bool _perTable = true;

  String get _baseUrl {
    final origin = AppConfig.appPublicUrl;
    if (origin.isEmpty) return '';
    return '$origin/m/${widget.cafeId}';
  }

  String _urlForTable(String? tableNo) {
    final base = _baseUrl;
    if (base.isEmpty) return '';
    final t = tableNo?.trim() ?? '';
    if (t.isEmpty) return base;
    return '$base?t=${Uri.encodeQueryComponent(t)}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sl<GetCafes>()();
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (cafes) {
        Cafe? found;
        for (final c in cafes) {
          if (c.id == widget.cafeId) {
            found = c;
            break;
          }
        }
        setState(() {
          _cafe = found;
          _loading = false;
          _error = found == null ? 'Cafe not found.' : null;
        });
      },
    );
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied')),
    );
  }

  Future<void> _printSheet() async {
    final cafe = _cafe;
    if (cafe == null || _baseUrl.isEmpty) {
      await showAppMessageDialog(
        context,
        title: 'QR',
        message: 'Set APP_PUBLIC_URL in app.env so QR links point to production.',
      );
      return;
    }

    final tables = _perTable
        ? List.generate(cafe.tableCount.clamp(1, 100), (i) => '${i + 1}')
        : <String?>[null];

    final doc = pw.Document();
    const perPage = 6;
    for (var i = 0; i < tables.length; i += perPage) {
      final chunk = tables.sublist(
        i,
        i + perPage > tables.length ? tables.length : i + perPage,
      );
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${cafe.name} — guest menu',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Scan to order on your phone',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 16),
                pw.Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final t in chunk)
                      pw.Container(
                        width: 240,
                        padding: const pw.EdgeInsets.all(14),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400),
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(10)),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text(
                              cafe.name,
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              t == null ? 'Menu' : 'Table $t',
                              style: const pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.SizedBox(height: 10),
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: _urlForTable(t),
                              width: 140,
                              height: 140,
                            ),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              'Scan to order',
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      name: '${cafe.name}_menu_qr',
      onLayout: (_) => doc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (!AppAccess.canManageCafeMenu(user, widget.cafeId)) {
      return const CafePosBackdrop(
        child: Center(child: Text('QR settings access denied.')),
      );
    }
    if (_loading) {
      return const CafePosBackdrop(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.text),
        ),
      );
    }
    if (_error != null || _cafe == null) {
      return CafePosBackdrop(
        child: CafePosEmptyState(
          icon: Icons.qr_code_2_rounded,
          title: 'Couldn’t load cafe',
          message: _error ?? 'Unknown error',
          action: AppButton(label: 'Retry', expand: false, onPressed: _load),
        ),
      );
    }

    final cafe = _cafe!;
    final cafeUrl = _urlForTable(null);
    final previewTable = '1';
    final tableUrl = _urlForTable(previewTable);

    return CafePosBackdrop(
      child: ListView(
        padding: CafePosSpace.page(context),
        children: [
          if (_baseUrl.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Set APP_PUBLIC_URL in assets/config/app.env so printed codes '
                'point at your live site.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
              ),
            ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Per table'),
              ),
              ButtonSegment(
                value: false,
                label: Text('Whole cafe'),
              ),
            ],
            selected: {_perTable},
            onSelectionChanged: (s) => setState(() => _perTable = s.first),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QrPreviewCard(
                  title: _perTable ? 'Table $previewTable' : 'Cafe menu',
                  url: _perTable ? tableUrl : cafeUrl,
                  cafeName: cafe.name,
                  onCopy: () => _copy(_perTable ? tableUrl : cafeUrl),
                ),
                if (_perTable) ...[
                  const SizedBox(width: 16),
                  _QrPreviewCard(
                    title: 'Cafe (no table)',
                    url: cafeUrl,
                    cafeName: cafe.name,
                    onCopy: () => _copy(cafeUrl),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: _perTable
                ? 'Print ${cafe.tableCount} table QRs'
                : 'Print cafe QR',
            enabled: _baseUrl.isNotEmpty,
            onPressed: _printSheet,
          ),
        ],
      ),
    );
  }
}

class _QrPreviewCard extends StatelessWidget {
  const _QrPreviewCard({
    required this.title,
    required this.url,
    required this.cafeName,
    required this.onCopy,
  });

  final String title;
  final String url;
  final String cafeName;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CafePosSpace.radius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 220,
          child: Column(
            children: [
              Text(
                cafeName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (url.isEmpty)
                const SizedBox(
                  height: 160,
                  child: Center(child: Text('No public URL')),
                )
              else
                QrImageView(
                  data: url,
                  size: 160,
                  backgroundColor: AppColors.background,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.text,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.text,
                  ),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: url.isEmpty ? null : onCopy,
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy link'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
