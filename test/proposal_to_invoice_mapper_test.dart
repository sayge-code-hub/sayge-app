import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/features/invoices/domain/services/proposal_to_invoice_mapper.dart';
import 'package:sayge_app/features/proposals/domain/entities/proposal.dart';

Proposal _proposal({
  String gstin = '27AAACM2931R2Z2',
  String place = 'Maharashtra (27)',
  List<ProposalLineItem> lines = const [],
}) {
  return Proposal(
    id: 'p1',
    referenceNo: 'QT-SY/26/10',
    quoteDate: DateTime(2026, 9, 1),
    expiryDate: DateTime(2026, 10, 1),
    placeOfSupply: place,
    vendorCode: 'VC1',
    entityCode: 'E1',
    billToName: 'Ketan Jain',
    billToCompany: 'Mahindra Finance',
    billToAddress: 'Worli, Mumbai',
    billToGstin: gstin,
    shipToName: '',
    shipToCompany: '',
    shipToAddress: '',
    shipToGstin: '',
    notes: '',
    lineItems: lines,
    subtotal: lines.fold<double>(0, (s, l) => s + l.totalRate),
    totalInWords: '',
  );
}

void main() {
  group('ProposalToInvoiceMapper', () {
    test('maps buyer and line totals into invoice draft', () {
      final draft = ProposalToInvoiceMapper.draftFrom(
        _proposal(
          lines: const [
            ProposalLineItem(
              id: 'l1',
              description: 'Flutter Engineer',
              monthlyRate: 100000,
              months: 2,
              days: 0,
              totalRate: 200000,
            ),
          ],
        ),
        at: DateTime(2026, 10, 11),
      );

      expect(draft.buyerCompany, 'Mahindra Finance');
      expect(draft.buyerName, 'Ketan Jain');
      expect(draft.buyerAddress, 'Worli, Mumbai');
      expect(draft.buyerGstin, '27AAACM2931R2Z2');
      expect(draft.placeOfSupply, 'Maharashtra');
      expect(draft.intraState, isTrue);
      expect(draft.poNumber, isEmpty);
      expect(draft.sourceProposalRef, 'QT-SY/26/10');
      expect(draft.lines, hasLength(1));
      expect(draft.lines.first.particulars, 'Flutter Engineer (2 months)');
      expect(draft.lines.first.amount, '200000');
    });

    test('infers inter-state when GSTIN state codes differ', () {
      final draft = ProposalToInvoiceMapper.draftFrom(
        _proposal(gstin: '29AAAAA0000A1Z5'),
      );
      expect(draft.intraState, isFalse);
    });

    test('uses day-based particulars when months are zero', () {
      final draft = ProposalToInvoiceMapper.draftFrom(
        _proposal(
          lines: const [
            ProposalLineItem(
              id: 'l1',
              description: 'Consulting',
              monthlyRate: 0,
              months: 0,
              days: 10,
              totalRate: 33333.33,
            ),
          ],
        ),
      );
      expect(draft.lines.first.particulars, 'Consulting (10 days)');
      expect(draft.lines.first.amount, '33333.33');
    });

    test('normalizePlaceOfSupply strips state code suffix', () {
      expect(
        ProposalToInvoiceMapper.normalizePlaceOfSupply('Karnataka (29)'),
        'Karnataka',
      );
      expect(
        ProposalToInvoiceMapper.normalizePlaceOfSupply(''),
        'Maharashtra',
      );
    });
  });
}
