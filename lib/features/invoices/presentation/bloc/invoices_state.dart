part of 'invoices_bloc.dart';

enum InvoicesStatus { initial, loading, ready, editing, saving, failure }

enum InvoicesView { list, form }

class InvoicesState extends Equatable {
  const InvoicesState({
    required this.status,
    required this.view,
    required this.invoices,
    required this.purchaseOrders,
    required this.draftInvoiceNo,
    required this.draftPlaceOfSupply,
    required this.draftPoNumber,
    required this.draftBuyerName,
    required this.draftBuyerCompany,
    required this.draftBuyerAddress,
    required this.draftBuyerGstin,
    required this.draftBuyerContact,
    required this.draftIntraState,
    required this.draftLines,
    this.editingId,
    this.draftInvoiceDate,
    this.errorMessage,
  });

  factory InvoicesState.initial() {
    return const InvoicesState(
      status: InvoicesStatus.initial,
      view: InvoicesView.list,
      invoices: [],
      purchaseOrders: [],
      draftInvoiceNo: '',
      draftPlaceOfSupply: AppInvoiceConfig.defaultPlaceOfSupply,
      draftPoNumber: '',
      draftBuyerName: '',
      draftBuyerCompany: '',
      draftBuyerAddress: '',
      draftBuyerGstin: '',
      draftBuyerContact: '',
      draftIntraState: AppInvoiceConfig.defaultIntraState,
      draftLines: [],
    );
  }

  final InvoicesStatus status;
  final InvoicesView view;
  final List<Invoice> invoices;
  final List<EmployeePurchaseOrder> purchaseOrders;
  final String draftInvoiceNo;
  final DateTime? draftInvoiceDate;
  final String draftPoNumber;
  final String draftPlaceOfSupply;
  final String draftBuyerName;
  final String draftBuyerCompany;
  final String draftBuyerAddress;
  final String draftBuyerGstin;
  final String draftBuyerContact;
  final bool draftIntraState;
  final List<InvoiceDraftLine> draftLines;
  /// When set, Save updates this invoice instead of creating a new one.
  final String? editingId;
  final String? errorMessage;

  bool get isEditing => editingId != null;

  InvoicesState copyWith({
    InvoicesStatus? status,
    InvoicesView? view,
    List<Invoice>? invoices,
    List<EmployeePurchaseOrder>? purchaseOrders,
    String? draftInvoiceNo,
    DateTime? draftInvoiceDate,
    String? draftPoNumber,
    String? draftPlaceOfSupply,
    String? draftBuyerName,
    String? draftBuyerCompany,
    String? draftBuyerAddress,
    String? draftBuyerGstin,
    String? draftBuyerContact,
    bool? draftIntraState,
    List<InvoiceDraftLine>? draftLines,
    String? editingId,
    String? errorMessage,
    bool clearError = false,
    bool clearEditingId = false,
  }) {
    return InvoicesState(
      status: status ?? this.status,
      view: view ?? this.view,
      invoices: invoices ?? this.invoices,
      purchaseOrders: purchaseOrders ?? this.purchaseOrders,
      draftInvoiceNo: draftInvoiceNo ?? this.draftInvoiceNo,
      draftInvoiceDate: draftInvoiceDate ?? this.draftInvoiceDate,
      draftPoNumber: draftPoNumber ?? this.draftPoNumber,
      draftPlaceOfSupply: draftPlaceOfSupply ?? this.draftPlaceOfSupply,
      draftBuyerName: draftBuyerName ?? this.draftBuyerName,
      draftBuyerCompany: draftBuyerCompany ?? this.draftBuyerCompany,
      draftBuyerAddress: draftBuyerAddress ?? this.draftBuyerAddress,
      draftBuyerGstin: draftBuyerGstin ?? this.draftBuyerGstin,
      draftBuyerContact: draftBuyerContact ?? this.draftBuyerContact,
      draftIntraState: draftIntraState ?? this.draftIntraState,
      draftLines: draftLines ?? this.draftLines,
      editingId: clearEditingId ? null : (editingId ?? this.editingId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        view,
        invoices,
        purchaseOrders,
        draftInvoiceNo,
        draftInvoiceDate,
        draftPoNumber,
        draftPlaceOfSupply,
        draftBuyerName,
        draftBuyerCompany,
        draftBuyerAddress,
        draftBuyerGstin,
        draftBuyerContact,
        draftIntraState,
        draftLines,
        editingId,
        errorMessage,
      ];
}
