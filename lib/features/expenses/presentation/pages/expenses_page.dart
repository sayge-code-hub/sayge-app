import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/billing/billing_write_guard.dart';
import '../../../../core/error/exceptions.dart';
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
import '../../../settings/domain/entities/client.dart';
import '../../../settings/presentation/bloc/clients/clients_bloc.dart';
import '../../data/datasources/expense_remote_datasource.dart';
import '../../domain/entities/expense.dart';
import '../../domain/usecases/expense_category_usecases.dart';
import '../bloc/expenses_bloc.dart';

Future<void> _openExpenseReceipt(BuildContext context, Expense expense) async {
  final path = (expense.receiptPath ?? '').trim();
  if (path.isEmpty) {
    await showAppMessageDialog(
      context,
      title: 'Receipt',
      message: 'No receipt is attached to this expense.',
    );
    return;
  }
  try {
    final url = await sl<ExpenseRemoteDataSource>().receiptDownloadUrl(path);
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      await showAppMessageDialog(
        context,
        title: 'Receipt',
        message: 'Could not open the receipt.',
      );
    }
  } on ServerException catch (e) {
    if (!context.mounted) return;
    await showAppMessageDialog(context, title: 'Receipt', message: e.message);
  } catch (_) {
    if (!context.mounted) return;
    await showAppMessageDialog(
      context,
      title: 'Receipt',
      message: 'Could not open the receipt.',
    );
  }
}

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    ClientsBloc? existingClients;
    try {
      existingClients = context.read<ClientsBloc>();
    } catch (_) {
      existingClients = null;
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<ExpensesBloc>()..add(const ExpensesStarted()),
        ),
        if (existingClients == null)
          BlocProvider(
            create: (_) => sl<ClientsBloc>()..add(const ClientsRequested()),
          )
        else
          BlocProvider<ClientsBloc>.value(value: existingClients),
      ],
      child: const _ExpensesBody(),
    );
  }
}

class _ExpensesBody extends StatelessWidget {
  const _ExpensesBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpensesBloc, ExpensesState>(
      listenWhen: (prev, next) =>
          (next.successMessage != null &&
              next.successMessage != prev.successMessage) ||
          (next.errorMessage != null &&
              next.errorMessage != prev.errorMessage &&
              !next.showingForm),
      listener: (context, state) async {
        final message = state.successMessage;
        if (message != null) {
          await showAppMessageDialog(context, message: message);
          return;
        }
        final error = state.errorMessage;
        if (error != null && !state.showingForm) {
          await showAppMessageDialog(
            context,
            title: 'Expenses',
            message: error,
          );
        }
      },
      builder: (context, state) {
        if (state.status == ExpensesStatus.initial ||
            (state.status == ExpensesStatus.loading && !state.showingForm)) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        if (state.showingForm) {
          return _ExpenseFormView(editing: state.editingExpense);
        }

        return _ExpenseList(state: state);
      },
    );
  }
}

class _ExpenseList extends StatefulWidget {
  const _ExpenseList({required this.state});

  final ExpensesState state;

  @override
  State<_ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends State<_ExpenseList> {
  String _query = '';

  List<Expense> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.state.expenses;
    return widget.state.expenses.where((e) {
      return e.madeFor.toLowerCase().contains(q) ||
          e.paidFrom.toLowerCase().contains(q) ||
          e.category.toLowerCase().contains(q) ||
          e.costCenterLabel.toLowerCase().contains(q) ||
          e.approvalStatus.label.toLowerCase().contains(q) ||
          e.amount.toString().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final isStaff = AppAccess.isStaff(sl<AuthSession>().user);
    final dateFormat = DateFormat('dd MMM yyyy');
    final expenses = _filtered;
    final textTheme = Theme.of(context).textTheme;
    final busy = widget.state.status == ExpensesStatus.saving;

    final newExpense = AppButton(
      label: 'New expense',
      expand: !isDesktop,
      enabled: !busy,
      onPressed: () =>
          context.read<ExpensesBloc>().add(const ExpenseFormOpened()),
    );

    Future<void> exportCsv() async {
      await CsvExport.download(
        filename: 'expenses.csv',
        headers: const [
          'Date',
          'Made for',
          'Amount',
          'Paid from',
          'Category',
          'Cost center',
          'Status',
        ],
        rows: [
          for (final e in widget.state.expenses)
            [
              e.reportingDate == null
                  ? ''
                  : dateFormat.format(e.reportingDate!.toLocal()),
              e.madeFor,
              e.amount,
              e.paidFrom,
              e.category,
              e.costCenterLabel,
              e.approvalStatus.label,
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
                        hintText: 'Search expenses…',
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Export CSV',
                      onPressed: widget.state.expenses.isEmpty
                          ? null
                          : exportCsv,
                      icon: const Icon(Icons.download),
                      color: AppColors.text,
                    ),
                    const SizedBox(width: 4),
                    newExpense,
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: AppListSearchField(
                        hintText: 'Search expenses…',
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Export CSV',
                      onPressed: widget.state.expenses.isEmpty
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
          child: widget.state.expenses.isEmpty
              ? Center(
                  child: Text(
                    'No expenses yet.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                )
              : expenses.isEmpty
              ? Center(
                  child: Text(
                    'No matching expenses.',
                    style: textTheme.bodyMedium?.copyWith(
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
                  itemCount: expenses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    final dateLabel = expense.reportingDate == null
                        ? ''
                        : dateFormat.format(expense.reportingDate!.toLocal());
                    final approving = widget.state.approvingId == expense.id;
                    final canEdit =
                        expense.approvalStatus == ExpenseApprovalStatus.pending;
                    return AppListCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  expense.madeFor,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    expense.costCenterLabel,
                                    expense.category,
                                    expense.paidFrom,
                                    if (dateLabel.isNotEmpty) dateLabel,
                                    if ((expense.receiptName ?? '').isNotEmpty)
                                      expense.receiptName!,
                                  ].where((e) => e.isNotEmpty).join(' · '),
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _ApprovalBadge(status: expense.approvalStatus),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    MoneyFormat.format(expense.amount),
                                    style: textTheme.titleMedium?.copyWith(
                                      fontSize: 13,
                                    ),
                                  ),
                                  if ((expense.receiptPath ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    AppListIconButton(
                                      tooltip: 'Open receipt',
                                      onPressed: busy
                                          ? null
                                          : () => _openExpenseReceipt(
                                                context,
                                                expense,
                                              ),
                                      icon: Icons.attach_file,
                                    ),
                                  if (canEdit)
                                    AppListIconButton(
                                      tooltip: 'Edit pending',
                                      onPressed: busy
                                          ? null
                                          : () => context
                                                .read<ExpensesBloc>()
                                                .add(
                                                  ExpenseEditOpened(expense),
                                                ),
                                      icon: Icons.edit_outlined,
                                    ),
                                ],
                              ),
                              if (isStaff &&
                                  expense.approvalStatus ==
                                      ExpenseApprovalStatus.pending) ...[
                                const SizedBox(height: 8),
                                if (approving)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.text,
                                    ),
                                  )
                                else
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => context
                                                  .read<ExpensesBloc>()
                                                  .add(
                                                    ExpenseApprovalChanged(
                                                      expenseId: expense.id,
                                                      status:
                                                          ExpenseApprovalStatus
                                                              .rejected,
                                                    ),
                                                  ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Reject',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => context
                                                  .read<ExpensesBloc>()
                                                  .add(
                                                    ExpenseApprovalChanged(
                                                      expenseId: expense.id,
                                                      status:
                                                          ExpenseApprovalStatus
                                                              .approved,
                                                    ),
                                                  ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.success,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Approve',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (!isDesktop) AppStickyActions(children: [newExpense]),
      ],
    );
  }
}

class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({required this.status});

  final ExpenseApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (status) {
      case ExpenseApprovalStatus.approved:
        color = AppColors.success;
      case ExpenseApprovalStatus.rejected:
        color = AppColors.error;
      case ExpenseApprovalStatus.pending:
        color = AppColors.highlight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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

class _ExpenseFormView extends StatefulWidget {
  const _ExpenseFormView({this.editing});

  final Expense? editing;

  @override
  State<_ExpenseFormView> createState() => _ExpenseFormViewState();
}

class _ExpenseFormViewState extends State<_ExpenseFormView> {
  late final TextEditingController _madeFor;
  late final TextEditingController _amount;
  late final TextEditingController _paidFrom;
  late final TextEditingController _dateCtrl;
  String? _category;
  List<String> _categories = Expense.categories;
  late String _costCenterId;
  late DateTime _expenseDate;
  Uint8List? _receiptBytes;
  String? _receiptFileName;
  String? _receiptMimeType;
  String? _existingReceiptName;

  final _dateFormat = DateFormat('dd-MM-yyyy');

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _madeFor = TextEditingController(text: editing?.madeFor ?? '');
    _amount = TextEditingController(
      text: editing == null
          ? ''
          : (editing.amount == editing.amount.roundToDouble()
                ? '${editing.amount.round()}'
                : editing.amount.toStringAsFixed(2)),
    );
    _paidFrom = TextEditingController(text: editing?.paidFrom ?? '');
    _category = editing?.category;
    _costCenterId = editing == null || editing.isCompanyExpense
        ? Expense.companyScopeId
        : (editing.clientId ?? Expense.companyScopeId);
    _expenseDate =
        editing?.expenseDate ?? editing?.createdAt?.toLocal() ?? DateTime.now();
    _dateCtrl = TextEditingController(text: _dateFormat.format(_expenseDate));
    _existingReceiptName = editing?.receiptName;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final result = await sl<GetExpenseCategoriesUseCase>()();
    if (!mounted) return;
    result.fold((_) {}, (items) {
      final names = items
          .map((category) => category.name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
      if (names.isEmpty) return;
      setState(() => _categories = names);
    });
  }

  List<String> get _categoryItems {
    final names = List<String>.from(_categories);
    final current = _category?.trim() ?? '';
    if (current.isNotEmpty && !names.contains(current)) {
      names.insert(0, current);
    }
    return names;
  }

  @override
  void dispose() {
    _madeFor.dispose();
    _amount.dispose();
    _paidFrom.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;
    setState(() {
      _receiptBytes = bytes;
      _receiptFileName = file.name;
      _receiptMimeType = 'application/octet-stream';
    });
  }

  void _clearPickedReceipt() {
    setState(() {
      _receiptBytes = null;
      _receiptFileName = null;
      _receiptMimeType = null;
    });
  }

  Future<void> _submit(List<Client> clients) async {
    if (!await ensureBillingWritable(context)) return;
    if (!mounted) return;
    final amount =
        double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;
    final isCompany = _costCenterId == Expense.companyScopeId;
    Client? client;
    if (!isCompany) {
      for (final c in clients) {
        if (c.id == _costCenterId) {
          client = c;
          break;
        }
      }
    }
    context.read<ExpensesBloc>().add(
      ExpenseSubmitted(
        Expense(
          id: widget.editing?.id ?? '',
          madeFor: _madeFor.text,
          amount: amount,
          paidFrom: _paidFrom.text,
          category: _category ?? '',
          clientId: isCompany ? null : client?.id,
          clientName: isCompany ? null : client?.name,
          expenseDate: _expenseDate,
        ),
        receiptBytes: _receiptBytes,
        receiptFileName: _receiptFileName,
        receiptMimeType: _receiptMimeType,
      ),
    );
  }

  Widget _fieldPair({
    required bool sideBySide,
    required Widget left,
    required Widget right,
  }) {
    if (!sideBySide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 12), right],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _receiptSlot({required bool sideBySide, required Widget child}) {
    if (!sideBySide) return child;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: child),
        const SizedBox(width: 12),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;
    final clients = Client.uniqueByCompany(
      context.watch<ClientsBloc>().state.clients.where((c) => c.isActive),
    );
    final costCenterIds = <String>[
      Expense.companyScopeId,
      ...clients.map((c) => c.id),
    ];
    final receiptLabel = _receiptFileName ?? _existingReceiptName;

    return BlocBuilder<ExpensesBloc, ExpensesState>(
      builder: (context, state) {
        final saving = state.status == ExpensesStatus.saving;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || saving) return;
            leaveFormIfConfirmed(
              context,
              () => context.read<ExpensesBloc>().add(
                const ExpenseFormCancelled(),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
                  children: [
                    _fieldPair(
                      sideBySide: isDesktop,
                      left: AppDropdown<String>(
                        label: 'Cost center',
                        value: costCenterIds.contains(_costCenterId)
                            ? _costCenterId
                            : Expense.companyScopeId,
                        items: costCenterIds,
                        itemLabel: (id) {
                          if (id == Expense.companyScopeId) {
                            return Expense.companyScopeLabel;
                          }
                          for (final c in clients) {
                            if (c.id == id) return c.name;
                          }
                          return id;
                        },
                        enabled: !saving,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _costCenterId = value);
                        },
                      ),
                      right: AppTextField(
                        label: 'Expense date',
                        controller: _dateCtrl,
                        readOnly: true,
                        enabled: !saving,
                        onTap: saving
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _expenseDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked == null) return;
                                setState(() {
                                  _expenseDate = picked;
                                  _dateCtrl.text = _dateFormat.format(picked);
                                });
                              },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _fieldPair(
                      sideBySide: isDesktop,
                      left: AppTextField(
                        label: 'Expense made for',
                        controller: _madeFor,
                        enabled: !saving,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      right: AppTextField(
                        label: 'Amount',
                        controller: _amount,
                        enabled: !saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        prefixText: '₹ ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _fieldPair(
                      sideBySide: isDesktop,
                      left: AppTextField(
                        label: 'Paid from',
                        controller: _paidFrom,
                        enabled: !saving,
                        textCapitalization: TextCapitalization.words,
                      ),
                      right: AppDropdown<String>(
                        label: 'Category',
                        value: _category,
                        items: _categoryItems,
                        itemLabel: (item) => item,
                        enabled: !saving,
                        onChanged: (value) => setState(() => _category = value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _receiptSlot(
                      sideBySide: isDesktop,
                      child: _ReceiptField(
                        fileName: receiptLabel,
                        enabled: !saving,
                        onPick: _pickReceipt,
                        onClear: _receiptBytes == null
                            ? null
                            : _clearPickedReceipt,
                      ),
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AppStickyActions(
                children: [
                  OutlinedButton(
                    onPressed: saving
                        ? null
                        : () => leaveFormIfConfirmed(
                            context,
                            () => context.read<ExpensesBloc>().add(
                              const ExpenseFormCancelled(),
                            ),
                          ),
                    child: const Text('Back'),
                  ),
                  AppButton(
                    label: saving
                        ? 'Saving…'
                        : (widget.editing == null ? 'Save' : 'Update expense'),
                    expand: true,
                    isLoading: saving,
                    enabled: !saving,
                    onPressed: () => _submit(clients),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReceiptField extends StatelessWidget {
  const _ReceiptField({
    required this.fileName,
    required this.enabled,
    required this.onPick,
    this.onClear,
  });

  final String? fileName;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = fileName?.trim() ?? '';
    final hasFile = name.isNotEmpty;

    return Column(
      key: const Key('expense-receipt-field'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Receipt',
          style: textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: enabled ? onPick : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 6, 11),
              child: Row(
                children: [
                  Icon(
                    hasFile ? Icons.description_outlined : Icons.attach_file,
                    size: 18,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasFile ? name : 'Attach receipt',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: hasFile ? AppColors.text : AppColors.textLight,
                      ),
                    ),
                  ),
                  if (onClear != null)
                    AppListIconButton(
                      icon: Icons.close,
                      tooltip: 'Remove',
                      iconSize: 16,
                      buttonSize: 28,
                      onPressed: enabled ? onClear : null,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
