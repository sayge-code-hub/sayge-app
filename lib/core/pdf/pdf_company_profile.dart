import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../features/settings/domain/entities/settings_entities.dart';
import '../config/app_invoice_config.dart';
import '../config/app_proposal_config.dart';

/// Seller block for PDF documents — prefers live [CompanyDetails], else config.
class PdfCompanyProfile {
  const PdfCompanyProfile({
    required this.displayName,
    required this.address,
    required this.gstin,
    required this.pan,
    required this.sacCode,
    required this.telephone,
    required this.email,
    required this.bankName,
    required this.bankAccountNo,
    required this.bankBranch,
    required this.bankIfsc,
    this.logoBytes,
    this.regionLabel = '',
  });

  final String displayName;
  final String address;
  final String gstin;
  final String pan;
  final String sacCode;
  final String telephone;
  final String email;
  final String bankName;
  final String bankAccountNo;
  final String bankBranch;
  final String bankIfsc;
  final Uint8List? logoBytes;
  final String regionLabel;

  static PdfCompanyProfile fromConfig() {
    return const PdfCompanyProfile(
      displayName: AppInvoiceConfig.companyName,
      address: AppInvoiceConfig.companyAddress,
      gstin: AppInvoiceConfig.companyGstin,
      pan: AppInvoiceConfig.companyPan,
      sacCode: AppInvoiceConfig.sacCode,
      telephone: AppInvoiceConfig.companyTel,
      email: AppInvoiceConfig.companyEmail,
      bankName: AppInvoiceConfig.bankName,
      bankAccountNo: AppInvoiceConfig.bankAccountNo,
      bankBranch: AppInvoiceConfig.bankBranch,
      bankIfsc: AppInvoiceConfig.bankIfsc,
      regionLabel: AppProposalConfig.companyRegion,
    );
  }

  static Future<PdfCompanyProfile> resolve(CompanyDetails? details) async {
    final base = fromConfig();
    if (details == null) {
      final bytes = await _assetBytes(AppInvoiceConfig.logoAsset);
      return PdfCompanyProfile(
        displayName: base.displayName,
        address: base.address,
        gstin: base.gstin,
        pan: base.pan,
        sacCode: base.sacCode,
        telephone: base.telephone,
        email: base.email,
        bankName: base.bankName,
        bankAccountNo: base.bankAccountNo,
        bankBranch: base.bankBranch,
        bankIfsc: base.bankIfsc,
        logoBytes: bytes,
        regionLabel: base.regionLabel,
      );
    }

    Uint8List? logo = await _networkBytes(details.logoUrl);
    logo ??= await _assetBytes(AppInvoiceConfig.logoAsset);

    String pick(String live, String fallback) {
      final t = live.trim();
      return t.isEmpty ? fallback : t;
    }

    return PdfCompanyProfile(
      displayName: pick(details.displayName, base.displayName),
      address: pick(details.address, base.address),
      gstin: pick(details.gstin, base.gstin),
      pan: pick(details.pan, base.pan),
      sacCode: pick(details.sacCode, base.sacCode),
      telephone: pick(details.telephone, base.telephone),
      email: pick(details.email, base.email),
      bankName: pick(details.bankName, base.bankName),
      bankAccountNo: pick(details.bankAccountNo, base.bankAccountNo),
      bankBranch: pick(details.bankBranch, base.bankBranch),
      bankIfsc: pick(details.bankIfsc, base.bankIfsc),
      logoBytes: logo,
      regionLabel: base.regionLabel,
    );
  }

  static Future<Uint8List?> _assetBytes(String path) async {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _networkBytes(String? url) async {
    final u = (url ?? '').trim();
    if (u.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(u));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return res.bodyBytes;
      }
    } catch (_) {}
    return null;
  }
}
