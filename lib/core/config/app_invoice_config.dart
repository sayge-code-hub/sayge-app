/// Configurable defaults for Tax Invoice documents.
abstract final class AppInvoiceConfig {
  static const String documentTitle = 'TAX INVOICE';

  static const String companyName = 'Sayge';
  static const String companyAddress =
      'Harsh Co-op society, Pandey Layout, Khamla Rd, Nagpur';
  static const String companyGstin = '27AEAFS9363N1ZB';
  static const String companyPan = 'AEAFS9363N';
  static const String sacCode = '998311';
  static const String companyTel = '8788681499';
  static const String companyEmail = 'humans@sayge.com';

  static const String defaultPlaceOfSupply = 'Maharashtra';

  /// Invoice number prefix (e.g. INV-SY/26/36).
  static const String invoicePrefix = 'INV-SY';

  /// Tax rates as percentages.
  static const double cgstRate = 9;
  static const double sgstRate = 9;
  static const double igstRate = 18;

  /// When true, apply CGST+SGST; when false, apply IGST.
  static const bool defaultIntraState = true;

  static const String bankName = 'The Maharashtra State Co. Op. Bank Ltd.';
  static const String bankAccountNo = '0056107040000517';
  static const String bankBranch = 'Deonagar Branch';
  static const String bankIfsc = 'MSCI0082051';

  static const String declaration =
      'We declare that this invoice shows the actual price of the services '
      'described and that all particulars are true and correct.';

  static const String gratitudeLine = 'We are grateful for your business.';
  static const String authorisedSignatoryLabel = 'Authorised Signatory';
  static const String signatureAsset = 'assets/images/proposal_signature.png';
  static const String logoAsset = 'assets/images/sayge_logo.png';
}
