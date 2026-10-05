import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_sticky_actions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/expense.dart';
import '../bloc/expenses_bloc.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ExpensesBloc>()..add(const ExpensesStarted()),
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
          next.successMessage != null &&
          next.successMessage != prev.successMessage,
      listener: (context, state) async {
        final message = state.successMessage;
        if (message != null) {
          await showAppMessageDialog(context, message: message);
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
          return const _ExpenseFormView();
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
                    const SizedBox(width: 12),
                    newExpense,
                  ],
                )
              : AppListSearchField(
                  hintText: 'Search expenses…',
                  onChanged: (value) => setState(() => _query = value),
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
                        final dateLabel = expense.createdAt == null
                            ? ''
                            : dateFormat.format(expense.createdAt!.toLocal());
                        final approving =
                            widget.state.approvingId == expense.id;
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
                                      style: textTheme.titleMedium
                                          ?.copyWith(fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        expense.category,
                                        expense.paidFrom,
                                        if (dateLabel.isNotEmpty) dateLabel,
                                      ].where((e) => e.isNotEmpty).join(' · '),
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontSize: 12,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _ApprovalBadge(
                                      status: expense.approvalStatus,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    MoneyFormat.format(expense.amount),
                                    style: textTheme.titleMedium
                                        ?.copyWith(fontSize: 13),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
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
                                              foregroundColor:
                                                  AppColors.success,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
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
  const _ExpenseFormView();

  @override
  State<_ExpenseFormView> createState() => _ExpenseFormViewState();
}

class _ExpenseFormViewState extends State<_ExpenseFormView> {
  final _madeFor = TextEditingController();
  final _amount = TextEditingController();
  final _paidFrom = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _madeFor.dispose();
    _amount.dispose();
    _paidFrom.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(
          _amount.text.trim().replaceAll(',', ''),
        ) ??
        0;
    context.read<ExpensesBloc>().add(
          ExpenseSubmitted(
            Expense(
              id: '',
              madeFor: _madeFor.text,
              amount: amount,
              paidFrom: _paidFrom.text,
              category: _category ?? '',
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;

    return BlocBuilder<ExpensesBloc, ExpensesState>(
      builder: (context, state) {
        final saving = state.status == ExpensesStatus.saving;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || saving) return;
            leaveFormIfConfirmed(
              context,
              () => context
                  .read<ExpensesBloc>()
                  .add(const ExpenseFormCancelled()),
            );
          },
          child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
                children: [
                  AppTextField(
                    label: 'Expense made for',
                    controller: _madeFor,
                    enabled: !saving,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
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
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Paid from',
                    controller: _paidFrom,
                    enabled: !saving,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  AppDropdown<String>(
                    label: 'Category',
                    value: _category,
                    items: Expense.categories,
                    itemLabel: (item) => item,
                    enabled: !saving,
                    onChanged: (value) => setState(() => _category = value),
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
                            () => context
                                .read<ExpensesBloc>()
                                .add(const ExpenseFormCancelled()),
                          ),
                  child: const Text('Back'),
                ),
                AppButton(
                  label: saving ? 'Saving…' : 'Save',
                  expand: true,
                  isLoading: saving,
                  enabled: !saving,
                  onPressed: _submit,
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
