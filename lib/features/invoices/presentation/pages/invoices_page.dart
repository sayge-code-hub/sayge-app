import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_display_config.dart';
import '../../../../core/config/app_invoice_config.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/csv_export.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_sticky_actions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../../hrms/domain/entities/employee.dart';
import '../../../hrms/domain/entities/employee_purchase_order.dart';
import '../../../hrms/presentation/bloc/employees/employees_bloc.dart';
import '../../../proposals/domain/entities/proposal.dart';
import '../../../settings/domain/entities/client.dart';
import '../../../settings/presentation/bloc/clients/clients_bloc.dart';
import '../../../settings/presentation/widgets/client_name_label.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/services/invoice_calculator.dart';
import '../bloc/invoices_bloc.dart';
import '../widgets/invoice_preview_dialog.dart';

class InvoicesPage extends StatelessWidget {
  const InvoicesPage({super.key, this.fromProposal});

  /// When set, opens a new invoice draft prefilled from this proposal.
  final Proposal? fromProposal;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = sl<InvoicesBloc>();
        final proposal = fromProposal;
        if (proposal != null) {
          bloc.add(InvoiceFromProposalOpened(proposal));
        } else {
          bloc.add(const InvoicesStarted());
        }
        return bloc;
      },
      child: const _InvoicesBody(),
    );
  }
}

class _InvoicesBody extends StatelessWidget {
  const _InvoicesBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InvoicesBloc, InvoicesState>(
      listenWhen: (prev, next) =>
          prev.errorMessage != next.errorMessage && next.errorMessage != null,
      listener: (context, state) {
        final message = state.errorMessage;
        if (message != null) {
          showAppMessageDialog(context, title: 'Invoices', message: message);
        }
      },
      builder: (context, state) {
        if (state.status == InvoicesStatus.initial ||
            (state.status == InvoicesStatus.loading &&
                state.view == InvoicesView.list &&
                state.invoices.isEmpty)) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }
        if (state.view == InvoicesView.form) {
          return _InvoiceFormView(
            key: ValueKey(
              'invoice-form-${state.editingId ?? state.draftInvoiceNo}',
            ),
            state: state,
          );
        }
        return _InvoiceList(state: state);
      },
    );
  }
}

class _InvoiceList extends StatefulWidget {
  const _InvoiceList({required this.state});

  final InvoicesState state;

  @override
  State<_InvoiceList> createState() => _InvoiceListState();
}

class _InvoiceListState extends State<_InvoiceList> {
  String _query = '';

  List<Invoice> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.state.invoices;
    return widget.state.invoices.where((invoice) {
      final party = invoice.buyerCompany.isNotEmpty
          ? invoice.buyerCompany
          : invoice.buyerName;
      return invoice.invoiceNo.toLowerCase().contains(q) ||
          party.toLowerCase().contains(q) ||
          invoice.buyerName.toLowerCase().contains(q) ||
          invoice.poNumber.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final dateFormat = DateFormat('dd MMM yyyy');
    final invoices = _filtered;

    final newInvoice = AppButton(
      label: 'New invoice',
      expand: !isDesktop,
      onPressed: () =>
          context.read<InvoicesBloc>().add(const InvoiceFormOpened()),
    );

    Future<void> exportCsv() async {
      final rows = widget.state.invoices;
      await CsvExport.download(
        filename: 'invoices.csv',
        headers: const [
          'Invoice No',
          'Date',
          'Buyer',
          'PO',
          'Total',
          'Payment Status',
          'Amount Paid',
          'Due Date',
        ],
        rows: [
          for (final invoice in rows)
            [
              invoice.invoiceNo,
              dateFormat.format(invoice.invoiceDate),
              invoice.buyerCompany.isNotEmpty
                  ? invoice.buyerCompany
                  : invoice.buyerName,
              invoice.poNumber,
              invoice.totalAmount,
              invoice.displayPaymentStatus().label,
              invoice.amountPaid,
              invoice.dueDate == null
                  ? ''
                  : dateFormat.format(invoice.dueDate!),
            ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 16,
            isDesktop ? 8 : 12,
            isDesktop ? 32 : 16,
            12,
          ),
          child: isDesktop
              ? Row(
                  children: [
                    Expanded(
                      child: AppListSearchField(
                        hintText: 'Search invoices…',
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Export CSV',
                      onPressed: widget.state.invoices.isEmpty
                          ? null
                          : exportCsv,
                      icon: const Icon(Icons.download),
                      color: AppColors.text,
                    ),
                    const SizedBox(width: 4),
                    newInvoice,
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: AppListSearchField(
                        hintText: 'Search invoices…',
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Export CSV',
                      onPressed: widget.state.invoices.isEmpty
                          ? null
                          : exportCsv,
                      icon: const Icon(Icons.download),
                      color: AppColors.text,
                    ),
                  ],
                ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: widget.state.invoices.isEmpty
              ? Center(
                  child: Text(
                    'No invoices yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                )
              : invoices.isEmpty
              ? Center(
                  child: Text(
                    'No matching invoices.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 32 : 16,
                    16,
                    isDesktop ? 32 : 16,
                    24,
                  ),
                  itemCount: invoices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final invoice = invoices[index];
                    final party = invoice.buyerCompany.isNotEmpty
                        ? invoice.buyerCompany
                        : invoice.buyerName;
                    return AppListCard(
                      onTap: () => showInvoicePreview(
                        context: context,
                        invoice: invoice,
                        onEdit: () => context.read<InvoicesBloc>().add(
                          InvoiceEditOpened(invoice),
                        ),
                        onClone: () => context.read<InvoicesBloc>().add(
                          InvoiceCloneOpened(invoice),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        invoice.invoiceNo,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontSize: 14),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _PaymentStatusChip(
                                      status: invoice.displayPaymentStatus(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (party.isNotEmpty) ...[
                                      Flexible(
                                        child: ClientNameLabel(
                                          name: party,
                                          contactName: invoice.buyerName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontSize: 12,
                                                color: AppColors.textLight,
                                              ),
                                          logoRadius: 7,
                                        ),
                                      ),
                                      Text(
                                        ' · ',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontSize: 12,
                                              color: AppColors.textLight,
                                            ),
                                      ),
                                    ],
                                    Flexible(
                                      child: Text(
                                        [
                                              dateFormat.format(
                                                invoice.invoiceDate,
                                              ),
                                              if (invoice.poNumber.isNotEmpty)
                                                'PO ${invoice.poNumber}',
                                            ]
                                            .where((e) => e.isNotEmpty)
                                            .join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontSize: 12,
                                              color: AppColors.textLight,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            MoneyFormat.format(invoice.totalAmount),
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          _InvoiceRowActions(
                            invoice: invoice,
                            compact: !isDesktop,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (!isDesktop) AppStickyActions(children: [newInvoice]),
      ],
    );
  }
}

class _InvoiceRowActions extends StatelessWidget {
  const _InvoiceRowActions({
    required this.invoice,
    required this.compact,
  });

  final Invoice invoice;
  final bool compact;

  void _markSent(BuildContext context) {
    context.read<InvoicesBloc>().add(
      InvoicePaymentUpdated(
        invoice: invoice,
        paymentStatus: InvoicePaymentStatus.sent,
        amountPaid: invoice.amountPaid,
        dueDate: invoice.dueDate,
        clearPaidAt: true,
      ),
    );
  }

  void _markPaid(BuildContext context) {
    context.read<InvoicesBloc>().add(
      InvoicePaymentUpdated(
        invoice: invoice,
        paymentStatus: InvoicePaymentStatus.paid,
        amountPaid: invoice.totalAmount,
        dueDate: invoice.dueDate,
        paidAt: DateTime.now(),
      ),
    );
  }

  void _markPartial(BuildContext context) {
    final half = (invoice.totalAmount / 2).roundToDouble();
    context.read<InvoicesBloc>().add(
      InvoicePaymentUpdated(
        invoice: invoice,
        paymentStatus: InvoicePaymentStatus.partial,
        amountPaid: half > 0 ? half : invoice.amountPaid,
        dueDate: invoice.dueDate,
        clearPaidAt: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use stored status so overdue display still allows Mark sent.
    final stored = invoice.paymentStatus;
    final canSend = stored == InvoicePaymentStatus.unpaid;
    final canPay = stored != InvoicePaymentStatus.paid;
    final canPartial =
        stored == InvoicePaymentStatus.unpaid ||
        stored == InvoicePaymentStatus.sent ||
        stored == InvoicePaymentStatus.overdue;

    if (compact) {
      return PopupMenuButton<String>(
        tooltip: 'Actions',
        icon: const Icon(Icons.more_vert, color: AppColors.text),
        onSelected: (value) {
          switch (value) {
            case 'sent':
              _markSent(context);
            case 'paid':
              _markPaid(context);
            case 'partial':
              _markPartial(context);
            case 'edit':
              context.read<InvoicesBloc>().add(InvoiceEditOpened(invoice));
            case 'clone':
              context.read<InvoicesBloc>().add(InvoiceCloneOpened(invoice));
            case 'download':
              context.read<InvoicesBloc>().add(
                InvoiceDownloadRequested(invoice),
              );
          }
        },
        itemBuilder: (context) => [
          if (canSend)
            const PopupMenuItem(value: 'sent', child: Text('Mark sent')),
          if (canPay)
            const PopupMenuItem(value: 'paid', child: Text('Mark paid')),
          if (canPartial)
            const PopupMenuItem(value: 'partial', child: Text('Mark partial')),
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'clone', child: Text('Clone')),
          const PopupMenuItem(value: 'download', child: Text('Download PDF')),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canSend)
          AppListIconButton(
            tooltip: 'Mark sent, awaiting payment',
            onPressed: () => _markSent(context),
            icon: Icons.send_outlined,
          ),
        if (canPay)
          AppListIconButton(
            tooltip: 'Mark paid',
            onPressed: () => _markPaid(context),
            icon: Icons.check_circle_outline,
          ),
        if (canPartial)
          AppListIconButton(
            tooltip: 'Mark partial',
            onPressed: () => _markPartial(context),
            icon: Icons.payments_outlined,
          ),
        AppListIconButton(
          tooltip: 'Edit',
          onPressed: () =>
              context.read<InvoicesBloc>().add(InvoiceEditOpened(invoice)),
          icon: Icons.edit_outlined,
        ),
        AppListIconButton(
          tooltip: 'Clone',
          onPressed: () =>
              context.read<InvoicesBloc>().add(InvoiceCloneOpened(invoice)),
          icon: Icons.copy_outlined,
        ),
        AppListIconButton(
          tooltip: 'Download PDF',
          onPressed: () => context.read<InvoicesBloc>().add(
            InvoiceDownloadRequested(invoice),
          ),
          icon: Icons.download,
        ),
      ],
    );
  }
}

class _PaymentStatusChip extends StatelessWidget {
  const _PaymentStatusChip({required this.status});

  final InvoicePaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (status) {
      case InvoicePaymentStatus.paid:
        color = AppColors.success;
      case InvoicePaymentStatus.partial:
        color = AppColors.highlight;
      case InvoicePaymentStatus.overdue:
        color = AppColors.error;
      case InvoicePaymentStatus.sent:
        color = AppColors.text;
      case InvoicePaymentStatus.unpaid:
        color = AppColors.textLight;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InvoiceFormView extends StatefulWidget {
  const _InvoiceFormView({super.key, required this.state});

  final InvoicesState state;

  @override
  State<_InvoiceFormView> createState() => _InvoiceFormViewState();
}

class _InvoiceFormViewState extends State<_InvoiceFormView> {
  late final TextEditingController _invoiceNo;
  late final TextEditingController _poNumber;
  late final TextEditingController _place;
  late final TextEditingController _buyerName;
  late final TextEditingController _buyerCompany;
  late final TextEditingController _buyerAddress;
  late final TextEditingController _buyerGstin;
  late final TextEditingController _buyerContact;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _amountPaid;
  late final TextEditingController _dueDateCtrl;
  late final List<_LineCtrls> _lines;
  late DateTime _invoiceDate;
  late bool _intraState;
  late InvoicePaymentStatus _paymentStatus;
  DateTime? _dueDate;
  DateTime? _paidAt;
  Client? _selectedClient;

  final _dateFormat = DateFormat('dd-MM-yyyy');

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    _invoiceNo = TextEditingController(text: s.draftInvoiceNo);
    _poNumber = TextEditingController(text: s.draftPoNumber);
    _place = TextEditingController(text: s.draftPlaceOfSupply);
    _buyerName = TextEditingController(text: s.draftBuyerName);
    _buyerCompany = TextEditingController(text: s.draftBuyerCompany);
    _buyerAddress = TextEditingController(text: s.draftBuyerAddress);
    _buyerGstin = TextEditingController(text: s.draftBuyerGstin);
    _buyerContact = TextEditingController(text: s.draftBuyerContact);
    _invoiceDate = s.draftInvoiceDate ?? DateTime.now();
    _dateCtrl = TextEditingController(text: _dateFormat.format(_invoiceDate));
    _intraState = s.draftIntraState;
    _paymentStatus = s.draftPaymentStatus;
    _amountPaid = TextEditingController(
      text: s.draftAmountPaid == 0
          ? ''
          : (s.draftAmountPaid == s.draftAmountPaid.roundToDouble()
                ? '${s.draftAmountPaid.round()}'
                : s.draftAmountPaid.toStringAsFixed(2)),
    );
    _dueDate = s.draftDueDate;
    _paidAt = s.draftPaidAt;
    _dueDateCtrl = TextEditingController(
      text: _dueDate == null ? '' : _dateFormat.format(_dueDate!),
    );
    _lines = [
      for (final line in s.draftLines)
        _LineCtrls(
          particulars: TextEditingController(text: line.particulars),
          amount: TextEditingController(text: line.amount),
        ),
    ];
    if (_lines.isEmpty) _lines.add(_LineCtrls.empty());
  }

  @override
  void dispose() {
    _invoiceNo.dispose();
    _poNumber.dispose();
    _place.dispose();
    _buyerName.dispose();
    _buyerCompany.dispose();
    _buyerAddress.dispose();
    _buyerGstin.dispose();
    _buyerContact.dispose();
    _dateCtrl.dispose();
    _amountPaid.dispose();
    _dueDateCtrl.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Invoice _draftInvoice() {
    final lines = <InvoiceLineItem>[];
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final amount = double.tryParse(line.amount.text.trim()) ?? 0;
      lines.add(
        InvoiceLineItem(
          id: 'preview_$i',
          particulars: line.particulars.text.trim(),
          amount: amount,
          sortOrder: i,
        ),
      );
    }
    final taxable = InvoiceCalculator.taxableAmount(lines);
    final tax = InvoiceCalculator.taxes(
      taxable: taxable,
      intraState: _intraState,
    );
    return Invoice(
      id: 'preview',
      invoiceNo: _invoiceNo.text.trim(),
      invoiceDate: _invoiceDate,
      poNumber: _poNumber.text.trim(),
      placeOfSupply: _place.text.trim(),
      buyerName: _buyerName.text.trim(),
      buyerCompany: _buyerCompany.text.trim(),
      buyerAddress: _buyerAddress.text.trim(),
      buyerGstin: _buyerGstin.text.trim(),
      buyerContact: _buyerContact.text.trim(),
      intraState: _intraState,
      lineItems: lines,
      taxableAmount: tax.taxable,
      cgstAmount: tax.cgst,
      sgstAmount: tax.sgst,
      igstAmount: tax.igst,
      totalAmount: tax.total,
      amountInWords: InvoiceCalculator.amountInWords(tax.total),
      paymentStatus: _paymentStatus,
      amountPaid: double.tryParse(_amountPaid.text.trim()) ?? 0,
      dueDate: _dueDate,
      paidAt: _paidAt,
    );
  }

  void _submit() {
    final paid = double.tryParse(_amountPaid.text.trim()) ?? 0;
    context.read<InvoicesBloc>().add(
      InvoiceSubmitted(
        invoiceNo: _invoiceNo.text,
        invoiceDate: _invoiceDate,
        poNumber: _poNumber.text,
        placeOfSupply: _place.text,
        buyerName: _buyerName.text,
        buyerCompany: _buyerCompany.text,
        buyerAddress: _buyerAddress.text,
        buyerGstin: _buyerGstin.text,
        buyerContact: _buyerContact.text,
        intraState: _intraState,
        paymentStatus: _paymentStatus,
        amountPaid: paid,
        dueDate: _dueDate,
        paidAt: _paymentStatus == InvoicePaymentStatus.paid
            ? (_paidAt ?? DateTime.now())
            : null,
        lines: [
          for (final line in _lines)
            InvoiceDraftLine(
              particulars: line.particulars.text,
              amount: line.amount.text,
            ),
        ],
      ),
    );
  }

  void _applyClient(Client? client) {
    setState(() {
      _selectedClient = client;
      if (client == null) return;
      _buyerCompany.text = client.name;
      _buyerName.text = client.contactName;
      _buyerContact.text = client.contactName;
      _buyerAddress.text = client.address;
      _buyerGstin.text = client.gstin;
    });
  }

  void _applyPo(EmployeePurchaseOrder? po) {
    if (po == null) return;
    if (!po.coversDate(_invoiceDate)) {
      final start = AppDates.compact.format(po.startDate);
      final end = AppDates.compact.format(po.endDate);
      showAppMessageDialog(
        context,
        title: 'Purchase order expired',
        message:
            'P.O. ${po.poNumber} is not valid for this invoice date. '
            'Valid period: $start to $end.',
      );
      return;
    }
    setState(() {
      _poNumber.text = po.poNumber;
    });
  }

  List<Employee> _candidates(List<Employee> employees) {
    final client = _selectedClient;
    if (client == null) {
      return employees.where((e) => e.isActive).toList()
        ..sort((a, b) => a.employeeName.compareTo(b.employeeName));
    }
    return employees.where((e) {
      if (!e.isActive) return false;
      if (e.clientId.isNotEmpty && e.clientId == client.id) return true;
      return e.client.trim().toLowerCase() == client.name.trim().toLowerCase();
    }).toList()..sort((a, b) => a.employeeName.compareTo(b.employeeName));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final saving = widget.state.status == InvoicesStatus.saving;
    final horizontal = isDesktop ? 32.0 : 16.0;
    final clients = context.watch<ClientsBloc>().state.clients;
    final employees = context.watch<EmployeesBloc>().state.employees;
    final pos = widget.state.purchaseOrders;
    final candidates = _candidates(employees);
    final draft = _draftInvoice();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || saving) return;
        leaveFormIfConfirmed(
          context,
          () => context.read<InvoicesBloc>().add(const InvoiceListRequested()),
        );
      },
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: saving
                    ? null
                    : () => leaveFormIfConfirmed(
                        context,
                        () => context.read<InvoicesBloc>().add(
                          const InvoiceListRequested(),
                        ),
                      ),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to list'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textLight,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
              children: [
                if ((widget.state.sourceProposalRef ?? '').isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.request_quote_outlined,
                          size: 18,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Draft from proposal ${widget.state.sourceProposalRef}. '
                            'Review tax and PO, then save.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontSize: 13, color: AppColors.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _card(
                  context,
                  title: 'Invoice details',
                  child: _grid(isDesktop, [
                    AppTextField(
                      label: 'Invoice No.',
                      controller: _invoiceNo,
                      enabled: !saving,
                    ),
                    AppTextField(
                      label: 'Date',
                      controller: _dateCtrl,
                      readOnly: true,
                      enabled: !saving,
                      onTap: saving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _invoiceDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked == null) return;
                              setState(() {
                                _invoiceDate = picked;
                                _dateCtrl.text = _dateFormat.format(picked);
                              });
                              final poNo = _poNumber.text.trim();
                              if (poNo.isEmpty || !mounted) return;
                              EmployeePurchaseOrder? match;
                              for (final po in pos) {
                                if (po.poNumber.trim().toLowerCase() ==
                                    poNo.toLowerCase()) {
                                  match = po;
                                  break;
                                }
                              }
                              if (match == null || match.coversDate(picked)) {
                                return;
                              }
                              if (!context.mounted) return;
                              final end = AppDates.compact.format(
                                match.endDate,
                              );
                              await showAppMessageDialog(
                                context,
                                title: 'Purchase order expired',
                                message:
                                    'P.O. $poNo ended on $end and is not valid '
                                    'for this invoice date. Clear or change the P.O.',
                              );
                            },
                    ),
                    AppTextField(
                      label: 'P.O. Number',
                      controller: _poNumber,
                      enabled: !saving,
                      hintText: 'Type or pick from list',
                      suffixIcon: pos.isEmpty
                          ? null
                          : PopupMenuButton<EmployeePurchaseOrder>(
                              tooltip: 'Select PO',
                              icon: const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: AppColors.textLight,
                              ),
                              onSelected: _applyPo,
                              itemBuilder: (context) => [
                                for (final po in pos)
                                  PopupMenuItem(
                                    value: po,
                                    enabled: po.coversDate(_invoiceDate),
                                    child: Text(
                                      po.coversDate(_invoiceDate)
                                          ? '${po.poNumber} (${po.employeeId})'
                                          : '${po.poNumber} · expired '
                                                '${AppDates.compact.format(po.endDate)}',
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    AppTextField(
                      label: 'Place of Supply',
                      controller: _place,
                      enabled: !saving,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _intraState
                                  ? 'Intra-state (CGST + SGST)'
                                  : 'Inter-state (IGST)',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontSize: 13,
                                    color: AppColors.text,
                                  ),
                            ),
                          ),
                          Switch(
                            value: _intraState,
                            activeThumbColor: AppColors.background,
                            activeTrackColor: AppColors.highlight,
                            inactiveThumbColor: AppColors.textLight,
                            inactiveTrackColor: AppColors.border,
                            trackOutlineColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return AppColors.highlight;
                              }
                              return AppColors.border;
                            }),
                            onChanged: saving
                                ? null
                                : (value) =>
                                      setState(() => _intraState = value),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                _card(
                  context,
                  title: 'Buyer',
                  child: Column(
                    children: [
                      AppDropdown<Client>(
                        label: 'Client',
                        value: () {
                          final selected = _selectedClient;
                          if (selected == null) return null;
                          for (final client in clients) {
                            if (client.id == selected.id) return client;
                          }
                          return null;
                        }(),
                        items: [
                          for (final client in clients)
                            if (client.isActive ||
                                (_selectedClient != null &&
                                    client.id == _selectedClient!.id))
                              client,
                        ],
                        itemLabel: (item) => item.displayLabel,
                        enabled: !saving,
                        hintText: 'Select client or type below',
                        onChanged: saving ? null : _applyClient,
                      ),
                      const SizedBox(height: 12),
                      _grid(isDesktop, [
                        AppTextField(
                          label: 'Buyer / Company',
                          controller: _buyerCompany,
                          enabled: !saving,
                        ),
                        AppTextField(
                          label: 'Contact person',
                          controller: _buyerContact,
                          enabled: !saving,
                        ),
                        AppTextField(
                          label: 'Address',
                          controller: _buyerAddress,
                          enabled: !saving,
                          maxLines: 3,
                        ),
                        AppTextField(
                          label: 'Buyer GSTIN',
                          controller: _buyerGstin,
                          enabled: !saving,
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  context,
                  title: 'Payment',
                  child: _grid(isDesktop, [
                    AppDropdown<InvoicePaymentStatus>(
                      label: 'Payment status',
                      value: _paymentStatus,
                      items: InvoicePaymentStatus.values
                          .where((s) => s != InvoicePaymentStatus.overdue)
                          .toList(),
                      itemLabel: (s) => s.label,
                      enabled: !saving,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _paymentStatus = value;
                          if (value == InvoicePaymentStatus.paid) {
                            _paidAt ??= DateTime.now();
                            if (_amountPaid.text.trim().isEmpty) {
                              _amountPaid.text = draft.totalAmount
                                  .round()
                                  .toString();
                            }
                          } else {
                            _paidAt = null;
                          }
                        });
                      },
                    ),
                    AppTextField(
                      label: 'Amount paid',
                      controller: _amountPaid,
                      enabled: !saving,
                      prefixText: AppDisplayConfig.currencySymbol,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                    AppTextField(
                      label: 'Due date',
                      controller: _dueDateCtrl,
                      readOnly: true,
                      enabled: !saving,
                      onTap: saving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _dueDate ?? _invoiceDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked == null) return;
                              setState(() {
                                _dueDate = picked;
                                _dueDateCtrl.text = _dateFormat.format(picked);
                              });
                            },
                      suffixIcon: _dueDate == null
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              onPressed: saving
                                  ? null
                                  : () => setState(() {
                                      _dueDate = null;
                                      _dueDateCtrl.clear();
                                    }),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                _card(
                  context,
                  title: 'Line items',
                  trailing: TextButton.icon(
                    onPressed: saving
                        ? null
                        : () => setState(() => _lines.add(_LineCtrls.empty())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add line'),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _lines.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _buildLine(i, saving, candidates),
                      ],
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Taxable  ${MoneyFormat.format(draft.taxableAmount)}',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                            ),
                            if (_intraState) ...[
                              Text(
                                'CGST ${AppInvoiceConfig.cgstRate.toStringAsFixed(0)}%  ${MoneyFormat.format(draft.cgstAmount)}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                              ),
                              Text(
                                'SGST ${AppInvoiceConfig.sgstRate.toStringAsFixed(0)}%  ${MoneyFormat.format(draft.sgstAmount)}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                              ),
                            ] else
                              Text(
                                'IGST ${AppInvoiceConfig.igstRate.toStringAsFixed(0)}%  ${MoneyFormat.format(draft.igstAmount)}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              'Total  ${MoneyFormat.format(draft.totalAmount)}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppStickyActions(
            children: [
              OutlinedButton(
                onPressed: saving
                    ? null
                    : () => showInvoicePreview(
                        context: context,
                        invoice: _draftInvoice(),
                      ),
                child: const Text('Preview'),
              ),
              AppButton(
                label: widget.state.isEditing
                    ? 'Update invoice'
                    : 'Save invoice',
                isLoading: saving,
                enabled: !saving,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLine(int index, bool saving, List<Employee> candidates) {
    final line = _lines[index];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Line ${index + 1}',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.textLight),
              ),
              const Spacer(),
              if (_lines.length > 1)
                IconButton(
                  onPressed: saving
                      ? null
                      : () => setState(() => _lines.removeAt(index).dispose()),
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
          AppTextField(
            label: 'Particulars',
            controller: line.particulars,
            enabled: !saving,
            hintText: candidates.isEmpty
                ? 'Type particulars'
                : 'Type freely or pick a candidate',
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            suffixIcon: candidates.isEmpty || saving
                ? null
                : PopupMenuButton<Employee>(
                    tooltip: 'Select candidate',
                    icon: const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: AppColors.textLight,
                    ),
                    onSelected: (employee) {
                      setState(() {
                        final designation = employee.designation.trim();
                        line.particulars.text = designation.isEmpty
                            ? employee.employeeName
                            : '${employee.employeeName} - $designation';
                        if (employee.monthlyCtc > 0) {
                          line.amount.text = employee.monthlyCtc
                              .round()
                              .toString();
                        }
                      });
                    },
                    itemBuilder: (context) => [
                      for (final employee in candidates)
                        PopupMenuItem(
                          value: employee,
                          child: Text(
                            employee.designation.trim().isEmpty
                                ? employee.employeeName
                                : '${employee.employeeName} - ${employee.designation}',
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          AppTextField(
            label: 'Amount',
            controller: line.amount,
            enabled: !saving,
            prefixText: AppDisplayConfig.currencySymbol,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: AppListCard.sectionPadding,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.highlight,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _grid(bool isDesktop, List<Widget> children) {
    if (!isDesktop) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 16),
            Expanded(
              child: i + 1 < children.length
                  ? children[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      if (i + 2 < children.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

class _LineCtrls {
  _LineCtrls({required this.particulars, required this.amount});

  factory _LineCtrls.empty() {
    return _LineCtrls(
      particulars: TextEditingController(),
      amount: TextEditingController(),
    );
  }

  final TextEditingController particulars;
  final TextEditingController amount;

  void dispose() {
    particulars.dispose();
    amount.dispose();
  }
}
