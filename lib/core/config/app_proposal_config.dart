/// Configurable defaults for Proposal documents.
/// Edit here to change company header, GST, and default terms.
abstract final class AppProposalConfig {
  static const String documentTitle = 'Proposal';

  static const String companyName = 'Sayge';
  static const String companyRegion = 'Maharashtra';
  static const String companyCountry = 'India';
  static const String companyGstin = '27AEAFS9363N1ZB';

  /// Used in Place of Supply (e.g. Maharashtra (27)).
  static const String defaultPlaceOfSupply = 'Maharashtra (27)';

  /// Days after quote date until expiry (default sample: 30).
  static const int defaultValidityDays = 30;

  /// Prefix for generated reference numbers (e.g. QT-SY/26/37).
  static const String referencePrefix = 'QT-SY';

  static const List<String> defaultNotes = [
    'Working days in a week: as per client standards.',
    'Public holidays: as per client standards.',
    'Candidate must extend hours in case troubleshooting is required.',
    'Candidates working on holidays will be taken care for adjustments from the automated system.',
  ];

  static const String authorisedSignatureLabel = 'Authorised Signature';
  static const String notesHeading = 'Notes / Comments';

  /// Stamp/signature shown bottom-right on proposal PDFs.
  static const String signatureAsset = 'assets/images/proposal_signature.png';
}
