import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_invoice_config.dart';
import '../../../../core/utils/pdf_saver.dart';
import '../../../hrms/domain/entities/employee_purchase_order.dart';
import '../../../hrms/domain/usecases/employee_purchase_order_usecases.dart';
import '../../data/invoice_pdf_builder.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/services/invoice_calculator.dart';
import '../../domain/usecases/invoice_usecases.dart';

part 'invoices_event.dart';
part 'invoices_state.dart';

class InvoicesBloc extends Bloc<InvoicesEvent, InvoicesState> {
  InvoicesBloc({
    required this.getInvoicesUseCase,
    required this.createInvoiceUseCase,
    required this.updateInvoiceUseCase,
    required this.getAllPosUseCase,
  }) : super(InvoicesState.initial()) {
    on<InvoicesStarted>(_onStarted);
    on<InvoiceFormOpened>(_onFormOpened);
    on<InvoiceEditOpened>(_onEditOpened);
    on<InvoiceCloneOpened>(_onCloneOpened);
    on<InvoiceListRequested>(_onList);
    on<InvoiceSubmitted>(_onSubmitted);
    on<InvoiceDownloadRequested>(_onDownload);
  }

  final GetInvoicesUseCase getInvoicesUseCase;
  final CreateInvoiceUseCase createInvoiceUseCase;
  final UpdateInvoiceUseCase updateInvoiceUseCase;
  final GetAllEmployeePurchaseOrdersUseCase getAllPosUseCase;

  Future<void> _onStarted(
    InvoicesStarted event,
    Emitter<InvoicesState> emit,
  ) async {
    emit(state.copyWith(status: InvoicesStatus.loading, clearError: true));
    final invoicesResult = await getInvoicesUseCase();
    final posResult = await getAllPosUseCase();

    final pos = posResult.fold((_) => <EmployeePurchaseOrder>[], (list) => list);

    invoicesResult.fold(
      (failure) => emit(
        state.copyWith(
          status: InvoicesStatus.failure,
          errorMessage: failure.message,
          purchaseOrders: pos,
        ),
      ),
      (list) => emit(
        state.copyWith(
          status: InvoicesStatus.ready,
          invoices: list,
          purchaseOrders: pos,
          view: InvoicesView.list,
          clearEditingId: true,
        ),
      ),
    );
  }

  Future<void> _onFormOpened(
    InvoiceFormOpened event,
    Emitter<InvoicesState> emit,
  ) async {
    final now = DateTime.now();
    final latest = await getInvoicesUseCase();
    final invoices = latest.fold((_) => state.invoices, (list) => list);
    final existing = invoices.map((e) => e.invoiceNo);
    emit(
      state.copyWith(
        view: InvoicesView.form,
        status: InvoicesStatus.editing,
        clearError: true,
        clearEditingId: true,
        invoices: invoices,
        draftInvoiceNo: InvoiceCalculator.generateInvoiceNo(
          existing: existing,
          at: now,
        ),
        draftInvoiceDate: now,
        draftPoNumber: '',
        draftPlaceOfSupply: AppInvoiceConfig.defaultPlaceOfSupply,
        draftBuyerName: '',
        draftBuyerCompany: '',
        draftBuyerAddress: '',
        draftBuyerGstin: '',
        draftBuyerContact: '',
        draftIntraState: AppInvoiceConfig.defaultIntraState,
        draftLines: const [InvoiceDraftLine(particulars: '', amount: '')],
      ),
    );
  }

  void _onEditOpened(
    InvoiceEditOpened event,
    Emitter<InvoicesState> emit,
  ) {
    emit(_formFromInvoice(event.invoice, editingId: event.invoice.id));
  }

  Future<void> _onCloneOpened(
    InvoiceCloneOpened event,
    Emitter<InvoicesState> emit,
  ) async {
    final now = DateTime.now();
    final latest = await getInvoicesUseCase();
    final invoices = latest.fold((_) => state.invoices, (list) => list);
    final existing = invoices.map((e) => e.invoiceNo);
    final source = event.invoice;

    emit(
      _formFromInvoice(
        source,
        clearEditingId: true,
        invoices: invoices,
        draftInvoiceNo: InvoiceCalculator.generateInvoiceNo(
          existing: existing,
          at: now,
        ),
        draftInvoiceDate: now,
      ),
    );
  }

  InvoicesState _formFromInvoice(
    Invoice invoice, {
    String? editingId,
    bool clearEditingId = false,
    List<Invoice>? invoices,
    String? draftInvoiceNo,
    DateTime? draftInvoiceDate,
  }) {
    final lines = invoice.lineItems.isEmpty
        ? const [InvoiceDraftLine(particulars: '', amount: '')]
        : [
            for (final line in invoice.lineItems)
              InvoiceDraftLine(
                particulars: line.particulars,
                amount: line.amount == line.amount.roundToDouble()
                    ? '${line.amount.round()}'
                    : line.amount.toStringAsFixed(2),
              ),
          ];

    return state.copyWith(
      view: InvoicesView.form,
      status: InvoicesStatus.editing,
      clearError: true,
      clearEditingId: clearEditingId,
      editingId: editingId,
      invoices: invoices,
      draftInvoiceNo: draftInvoiceNo ?? invoice.invoiceNo,
      draftInvoiceDate: draftInvoiceDate ?? invoice.invoiceDate,
      draftPoNumber: invoice.poNumber,
      draftPlaceOfSupply: invoice.placeOfSupply,
      draftBuyerName: invoice.buyerName,
      draftBuyerCompany: invoice.buyerCompany,
      draftBuyerAddress: invoice.buyerAddress,
      draftBuyerGstin: invoice.buyerGstin,
      draftBuyerContact: invoice.buyerContact,
      draftIntraState: invoice.intraState,
      draftLines: lines,
    );
  }

  Future<void> _onList(
    InvoiceListRequested event,
    Emitter<InvoicesState> emit,
  ) async {
    emit(
      state.copyWith(
        view: InvoicesView.list,
        clearError: true,
        clearEditingId: true,
      ),
    );
    add(const InvoicesStarted());
  }

  Future<void> _onSubmitted(
    InvoiceSubmitted event,
    Emitter<InvoicesState> emit,
  ) async {
    final lines = <InvoiceLineItem>[];
    for (var i = 0; i < event.lines.length; i++) {
      final draft = event.lines[i];
      final particulars = draft.particulars.trim();
      final amount = double.tryParse(draft.amount.trim()) ?? 0;
      if (particulars.isEmpty && amount <= 0) continue;
      if (particulars.isEmpty) {
        emit(
          state.copyWith(
            status: InvoicesStatus.failure,
            errorMessage: 'Line ${i + 1}: enter particulars',
          ),
        );
        return;
      }
      if (amount <= 0) {
        emit(
          state.copyWith(
            status: InvoicesStatus.failure,
            errorMessage: 'Line ${i + 1}: enter a valid amount',
          ),
        );
        return;
      }
      lines.add(
        InvoiceLineItem(
          id: 'inv_line_${DateTime.now().microsecondsSinceEpoch}_$i',
          particulars: particulars,
          amount: amount,
          sortOrder: i,
        ),
      );
    }

    final invoiceNo = event.invoiceNo.trim();
    if (invoiceNo.isEmpty) {
      emit(
        state.copyWith(
          status: InvoicesStatus.failure,
          errorMessage: 'Invoice number is required',
        ),
      );
      return;
    }
    if (lines.isEmpty) {
      emit(
        state.copyWith(
          status: InvoicesStatus.failure,
          errorMessage: 'Add at least one line item',
        ),
      );
      return;
    }

    final editingId = state.editingId;
    emit(state.copyWith(status: InvoicesStatus.saving, clearError: true));

    final latest = await getInvoicesUseCase();
    final competitors = latest.fold(
      (_) => state.invoices,
      (list) => list,
    ).where((e) => e.id != editingId).map((e) => e.invoiceNo);
    if (InvoiceCalculator.isInvoiceNoTaken(invoiceNo, competitors)) {
      emit(
        state.copyWith(
          status: InvoicesStatus.failure,
          errorMessage:
              'Invoice number "$invoiceNo" already exists. '
              'Use ${InvoiceCalculator.generateInvoiceNo(existing: competitors)} '
              'or another unused number.',
        ),
      );
      return;
    }

    final taxable = InvoiceCalculator.taxableAmount(lines);
    final tax = InvoiceCalculator.taxes(
      taxable: taxable,
      intraState: event.intraState,
    );

    final invoice = Invoice(
      id: editingId ?? 'inv_${DateTime.now().microsecondsSinceEpoch}',
      invoiceNo: invoiceNo,
      invoiceDate: event.invoiceDate,
      poNumber: event.poNumber.trim(),
      placeOfSupply: event.placeOfSupply.trim(),
      buyerName: event.buyerName.trim(),
      buyerCompany: event.buyerCompany.trim(),
      buyerAddress: event.buyerAddress.trim(),
      buyerGstin: event.buyerGstin.trim(),
      buyerContact: event.buyerContact.trim(),
      intraState: event.intraState,
      lineItems: lines,
      taxableAmount: tax.taxable,
      cgstAmount: tax.cgst,
      sgstAmount: tax.sgst,
      igstAmount: tax.igst,
      totalAmount: tax.total,
      amountInWords: InvoiceCalculator.amountInWords(tax.total),
    );

    final result = editingId == null
        ? await createInvoiceUseCase(invoice)
        : await updateInvoiceUseCase(invoice);

    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: InvoicesStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
      (saved) async {
        final refreshed = await getInvoicesUseCase();
        refreshed.fold(
          (_) => emit(
            state.copyWith(
              status: InvoicesStatus.ready,
              view: InvoicesView.list,
              clearEditingId: true,
              invoices: editingId == null
                  ? [saved, ...state.invoices]
                  : [
                      for (final item in state.invoices)
                        if (item.id == saved.id) saved else item,
                    ],
            ),
          ),
          (list) => emit(
            state.copyWith(
              status: InvoicesStatus.ready,
              view: InvoicesView.list,
              clearEditingId: true,
              invoices: list,
            ),
          ),
        );
      },
    );
  }

  Future<void> _onDownload(
    InvoiceDownloadRequested event,
    Emitter<InvoicesState> emit,
  ) async {
    try {
      final doc = await InvoicePdfBuilder.build(event.invoice);
      final bytes = await doc.save();
      final name =
          'Invoice_${event.invoice.invoiceNo.replaceAll(RegExp(r"[^\w.\-]+"), "_")}.pdf';
      await savePdfBytes(bytes: bytes, filename: name);
    } catch (_) {
      emit(
        state.copyWith(
          status: InvoicesStatus.failure,
          errorMessage: 'Could not download invoice PDF.',
        ),
      );
      emit(state.copyWith(status: InvoicesStatus.ready, clearError: true));
    }
  }
}
