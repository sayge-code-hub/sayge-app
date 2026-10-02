import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_proposal_config.dart';
import '../../../../core/utils/pdf_saver.dart';
import '../../data/proposal_pdf_builder.dart';
import '../../domain/entities/proposal.dart';
import '../../domain/services/proposal_calculator.dart';
import '../../domain/usecases/proposal_usecases.dart';

part 'proposals_event.dart';
part 'proposals_state.dart';

class ProposalsBloc extends Bloc<ProposalsEvent, ProposalsState> {
  ProposalsBloc({
    required this.getProposalsUseCase,
    required this.createProposalUseCase,
    required this.updateProposalUseCase,
  }) : super(ProposalsState.initial()) {
    on<ProposalsStarted>(_onStarted);
    on<ProposalFormOpened>(_onFormOpened);
    on<ProposalEditOpened>(_onEditOpened);
    on<ProposalCloneOpened>(_onCloneOpened);
    on<ProposalFormFieldChanged>(_onFieldChanged);
    on<ProposalLineChanged>(_onLineChanged);
    on<ProposalLineAdded>(_onLineAdded);
    on<ProposalLineRemoved>(_onLineRemoved);
    on<ProposalCopyShipFromBill>(_onCopyShip);
    on<ProposalSubmitted>(_onSubmitted);
    on<ProposalDownloadRequested>(_onDownload);
    on<ProposalListRequested>(_onList);
  }

  final GetProposalsUseCase getProposalsUseCase;
  final CreateProposalUseCase createProposalUseCase;
  final UpdateProposalUseCase updateProposalUseCase;

  Future<void> _onStarted(
    ProposalsStarted event,
    Emitter<ProposalsState> emit,
  ) async {
    emit(state.copyWith(status: ProposalsStatus.loading, clearError: true));
    final result = await getProposalsUseCase();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ProposalsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (list) => emit(
        state.copyWith(
          status: ProposalsStatus.ready,
          proposals: list,
          view: ProposalsView.list,
          clearEditingId: true,
        ),
      ),
    );
  }

  Future<void> _onFormOpened(
    ProposalFormOpened event,
    Emitter<ProposalsState> emit,
  ) async {
    final now = DateTime.now();
    final latest = await getProposalsUseCase();
    final proposals = latest.fold((_) => state.proposals, (list) => list);
    final existing = proposals.map((e) => e.referenceNo);

    emit(
      state.copyWith(
        view: ProposalsView.form,
        status: ProposalsStatus.editing,
        clearError: true,
        clearEditingId: true,
        proposals: proposals,
        referenceNo: ProposalCalculator.generateReferenceNo(
          existing: existing,
          at: now,
        ),
        quoteDate: now,
        expiryDate: ProposalCalculator.defaultExpiry(now),
        placeOfSupply: AppProposalConfig.defaultPlaceOfSupply,
        vendorCode: '',
        entityCode: '',
        billToName: '',
        billToCompany: '',
        billToAddress: '',
        billToGstin: '',
        shipToName: '',
        shipToCompany: '',
        shipToAddress: '',
        shipToGstin: '',
        notes: ProposalCalculator.defaultNotesText(),
        draftLines: [
          const DraftLine(
            description: '',
            monthlyRate: '',
            months: '1',
            days: '0',
          ),
        ],
      ),
    );
  }

  void _onEditOpened(
    ProposalEditOpened event,
    Emitter<ProposalsState> emit,
  ) {
    emit(_formFromProposal(event.proposal, editingId: event.proposal.id));
  }

  Future<void> _onCloneOpened(
    ProposalCloneOpened event,
    Emitter<ProposalsState> emit,
  ) async {
    final now = DateTime.now();
    final latest = await getProposalsUseCase();
    final proposals = latest.fold((_) => state.proposals, (list) => list);
    final existing = proposals.map((e) => e.referenceNo);
    final source = event.proposal;

    emit(
      _formFromProposal(
        source,
        editingId: null,
        clearEditingId: true,
        proposals: proposals,
        referenceNo: ProposalCalculator.generateReferenceNo(
          existing: existing,
          at: now,
        ),
        quoteDate: now,
        expiryDate: ProposalCalculator.defaultExpiry(now),
      ),
    );
  }

  ProposalsState _formFromProposal(
    Proposal proposal, {
    String? editingId,
    bool clearEditingId = false,
    List<Proposal>? proposals,
    String? referenceNo,
    DateTime? quoteDate,
    DateTime? expiryDate,
  }) {
    final lines = proposal.lineItems.isEmpty
        ? [
            const DraftLine(
              description: '',
              monthlyRate: '',
              months: '1',
              days: '0',
            ),
          ]
        : [
            for (final line in proposal.lineItems)
              DraftLine(
                description: line.description,
                monthlyRate: line.monthlyRate.toStringAsFixed(
                  line.monthlyRate == line.monthlyRate.roundToDouble() ? 0 : 2,
                ),
                months: '${line.months}',
                days: '${line.days}',
              ),
          ];

    return state.copyWith(
      view: ProposalsView.form,
      status: ProposalsStatus.editing,
      clearError: true,
      clearEditingId: clearEditingId,
      editingId: editingId,
      proposals: proposals,
      referenceNo: referenceNo ?? proposal.referenceNo,
      quoteDate: quoteDate ?? proposal.quoteDate,
      expiryDate: expiryDate ?? proposal.expiryDate,
      placeOfSupply: proposal.placeOfSupply,
      vendorCode: proposal.vendorCode,
      entityCode: proposal.entityCode,
      billToName: proposal.billToName,
      billToCompany: proposal.billToCompany,
      billToAddress: proposal.billToAddress,
      billToGstin: proposal.billToGstin,
      shipToName: proposal.shipToName,
      shipToCompany: proposal.shipToCompany,
      shipToAddress: proposal.shipToAddress,
      shipToGstin: proposal.shipToGstin,
      notes: proposal.notes,
      draftLines: lines,
    );
  }

  void _onFieldChanged(
    ProposalFormFieldChanged event,
    Emitter<ProposalsState> emit,
  ) {
    emit(
      state.copyWith(
        referenceNo: event.referenceNo,
        quoteDate: event.quoteDate,
        expiryDate: event.expiryDate,
        placeOfSupply: event.placeOfSupply,
        vendorCode: event.vendorCode,
        entityCode: event.entityCode,
        billToName: event.billToName,
        billToCompany: event.billToCompany,
        billToAddress: event.billToAddress,
        billToGstin: event.billToGstin,
        shipToName: event.shipToName,
        shipToCompany: event.shipToCompany,
        shipToAddress: event.shipToAddress,
        shipToGstin: event.shipToGstin,
        notes: event.notes,
        status: ProposalsStatus.editing,
        clearError: true,
      ),
    );
  }

  void _onLineChanged(
    ProposalLineChanged event,
    Emitter<ProposalsState> emit,
  ) {
    final lines = [...state.draftLines];
    if (event.index < 0 || event.index >= lines.length) return;
    final current = lines[event.index];
    lines[event.index] = current.copyWith(
      description: event.description,
      monthlyRate: event.monthlyRate,
      months: event.months,
      days: event.days,
    );
    emit(state.copyWith(draftLines: lines, clearError: true));
  }

  void _onLineAdded(ProposalLineAdded event, Emitter<ProposalsState> emit) {
    emit(
      state.copyWith(
        draftLines: [
          ...state.draftLines,
          const DraftLine(
            description: '',
            monthlyRate: '',
            months: '1',
            days: '0',
          ),
        ],
      ),
    );
  }

  void _onLineRemoved(
    ProposalLineRemoved event,
    Emitter<ProposalsState> emit,
  ) {
    if (state.draftLines.length <= 1) return;
    final lines = [...state.draftLines]..removeAt(event.index);
    emit(state.copyWith(draftLines: lines));
  }

  void _onCopyShip(
    ProposalCopyShipFromBill event,
    Emitter<ProposalsState> emit,
  ) {
    emit(
      state.copyWith(
        shipToName: state.billToName,
        shipToCompany: state.billToCompany,
        shipToAddress: state.billToAddress,
        shipToGstin: state.billToGstin,
      ),
    );
  }

  Future<void> _onSubmitted(
    ProposalSubmitted event,
    Emitter<ProposalsState> emit,
  ) async {
    final snapshot = state.copyWith(
      referenceNo: event.referenceNo,
      quoteDate: event.quoteDate,
      expiryDate: event.expiryDate,
      placeOfSupply: event.placeOfSupply,
      vendorCode: event.vendorCode,
      entityCode: event.entityCode,
      billToName: event.billToName,
      billToCompany: event.billToCompany,
      billToAddress: event.billToAddress,
      billToGstin: event.billToGstin,
      shipToName: event.shipToName,
      shipToCompany: event.shipToCompany,
      shipToAddress: event.shipToAddress,
      shipToGstin: event.shipToGstin,
      notes: event.notes,
      draftLines: event.lines,
    );

    final validation = snapshot.validateForm();
    if (validation != null) {
      emit(
        snapshot.copyWith(
          status: ProposalsStatus.failure,
          errorMessage: validation,
        ),
      );
      return;
    }

    final referenceNo = snapshot.referenceNo.trim();
    final editingId = snapshot.editingId;
    emit(snapshot.copyWith(status: ProposalsStatus.saving, clearError: true));

    final latest = await getProposalsUseCase();
    final competitors = latest.fold(
      (_) => state.proposals,
      (list) => list,
    ).where((e) => e.id != editingId).map((e) => e.referenceNo);
    if (ProposalCalculator.isReferenceNoTaken(referenceNo, competitors)) {
      emit(
        snapshot.copyWith(
          status: ProposalsStatus.failure,
          errorMessage:
              'Reference number "$referenceNo" already exists. '
              'Use ${ProposalCalculator.generateReferenceNo(existing: competitors)} '
              'or another unused number.',
        ),
      );
      return;
    }

    final lines = <ProposalLineItem>[];
    for (var i = 0; i < snapshot.draftLines.length; i++) {
      final draft = snapshot.draftLines[i];
      final rate = double.parse(draft.monthlyRate.trim());
      final months = int.parse(draft.months.trim());
      final days = int.parse(draft.days.trim());
      final total = ProposalCalculator.lineTotal(
        monthlyRate: rate,
        months: months,
        days: days,
      );
      lines.add(
        ProposalLineItem(
          id: 'line_${DateTime.now().microsecondsSinceEpoch}_$i',
          description: draft.description.trim(),
          monthlyRate: rate,
          months: months,
          days: days,
          totalRate: total,
          sortOrder: i,
        ),
      );
    }

    final subtotal = ProposalCalculator.subtotal(lines);
    final proposal = Proposal(
      id: editingId ?? 'prop_${DateTime.now().microsecondsSinceEpoch}',
      referenceNo: referenceNo,
      quoteDate: snapshot.quoteDate!,
      expiryDate: snapshot.expiryDate!,
      placeOfSupply: snapshot.placeOfSupply.trim(),
      vendorCode: snapshot.vendorCode.trim(),
      entityCode: snapshot.entityCode.trim(),
      billToName: snapshot.billToName.trim(),
      billToCompany: snapshot.billToCompany.trim(),
      billToAddress: snapshot.billToAddress.trim(),
      billToGstin: snapshot.billToGstin.trim(),
      shipToName: snapshot.shipToName.trim(),
      shipToCompany: snapshot.shipToCompany.trim(),
      shipToAddress: snapshot.shipToAddress.trim(),
      shipToGstin: snapshot.shipToGstin.trim(),
      notes: snapshot.notes.trim(),
      lineItems: lines,
      subtotal: subtotal,
      totalInWords: ProposalCalculator.amountInWords(subtotal),
    );

    final result = editingId == null
        ? await createProposalUseCase(proposal)
        : await updateProposalUseCase(proposal);

    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: ProposalsStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
      (saved) async {
        final refreshed = await getProposalsUseCase();
        refreshed.fold(
          (_) => emit(
            state.copyWith(
              status: ProposalsStatus.ready,
              view: ProposalsView.list,
              clearEditingId: true,
              proposals: editingId == null
                  ? [saved, ...state.proposals]
                  : [
                      for (final item in state.proposals)
                        if (item.id == saved.id) saved else item,
                    ],
            ),
          ),
          (list) => emit(
            state.copyWith(
              status: ProposalsStatus.ready,
              view: ProposalsView.list,
              clearEditingId: true,
              proposals: list,
            ),
          ),
        );
      },
    );
  }

  Future<void> _onDownload(
    ProposalDownloadRequested event,
    Emitter<ProposalsState> emit,
  ) async {
    try {
      final doc = await ProposalPdfBuilder.build(event.proposal);
      final bytes = await doc.save();
      final name =
          'Proposal_${event.proposal.referenceNo.replaceAll(RegExp(r"[^\w.\-]+"), "_")}.pdf';
      await savePdfBytes(bytes: bytes, filename: name);
    } catch (_) {
      emit(
        state.copyWith(
          status: ProposalsStatus.failure,
          errorMessage: 'Could not download proposal PDF.',
        ),
      );
      emit(state.copyWith(status: ProposalsStatus.ready, clearError: true));
    }
  }

  Future<void> _onList(
    ProposalListRequested event,
    Emitter<ProposalsState> emit,
  ) async {
    emit(
      state.copyWith(
        view: ProposalsView.list,
        clearError: true,
        clearEditingId: true,
      ),
    );
    add(const ProposalsStarted());
  }
}
