import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

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
          prev.status != next.status && next.status == ExpensesStatus.success,
      listener: (context, state) async {
        await showAppMessageDialog(
          context,
          message: 'Expense saved',
        );
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
          e.amount.toString().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final dateFormat = DateFormat('dd MMM yyyy');
    final expenses = _filtered;
    final textTheme = Theme.of(context).textTheme;

    final newExpense = AppButton(
      label: 'New expense',
      expand: !isDesktop,
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
                        return AppListCard(
                          child: Row(
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
                                  ],
                                ),
                              ),
                              Text(
                                MoneyFormat.format(expense.amount),
                                style: textTheme.titleMedium
                                    ?.copyWith(fontSize: 13),
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

        return Column(
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
                      : () => context
                          .read<ExpensesBloc>()
                          .add(const ExpenseFormCancelled()),
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
        );
      },
    );
  }
}
