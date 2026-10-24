import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/core/config/app_invoice_config.dart';
import 'package:sayge_app/core/pdf/pdf_company_profile.dart';
import 'package:sayge_app/features/settings/domain/entities/settings_entities.dart';

void main() {
  test('resolveSync prefers company_details bank fields', () {
    const details = CompanyDetails(
      id: 'company_sayge',
      name: 'sayge',
      displayName: 'Sayge Live',
      address: 'Live address',
      gstin: '27AAAAA0000A1Z5',
      pan: 'AAAAA0000A',
      sacCode: '998311',
      telephone: '9999999999',
      email: 'billing@sayge.in',
      bankName: 'Live Bank',
      bankAccountNo: '1234567890',
      bankBranch: 'Live Branch',
      bankIfsc: 'LIVE0001234',
    );

    final profile = PdfCompanyProfile.resolveSync(details);

    expect(profile.displayName, 'Sayge Live');
    expect(profile.bankName, 'Live Bank');
    expect(profile.bankAccountNo, '1234567890');
    expect(profile.bankIfsc, 'LIVE0001234');
  });

  test('resolveSync falls back when company is null', () {
    final profile = PdfCompanyProfile.resolveSync(null);
    expect(profile.displayName, AppInvoiceConfig.companyName);
    expect(profile.bankAccountNo, AppInvoiceConfig.bankAccountNo);
  });

  test('AppInvoiceConfig does not embed live bank account numbers', () {
    expect(AppInvoiceConfig.bankAccountNo, isEmpty);
    expect(AppInvoiceConfig.bankIfsc, isEmpty);
  });
}
