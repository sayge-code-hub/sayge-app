import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/presentation/bloc/expenses_bloc.dart';
import '../../../hrms/domain/entities/employee.dart';
import '../../../hrms/presentation/bloc/employees/employees_bloc.dart';
import '../../../hrms/presentation/pages/my_details_page.dart';
import '../../../hrms/presentation/widgets/employee_form_layout.dart';
import '../../../payroll/presentation/bloc/payroll_bloc.dart';

/// Single home for employees: profile, compensation, salary slip, expenses.
class EmployeeDashboardPage extends StatelessWidget {
  const EmployeeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<PayrollBloc>()..add(const PayrollStarted()),
        ),
        BlocProvider(
          create: (_) => sl<ExpensesBloc>()..add(const ExpensesStarted()),
        ),
      ],
      child: const _DashboardBody(),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpensesBloc, ExpensesState>(
      builder: (context, expenseState) {
        if (expenseState.showingForm) {
          return const _DashboardExpenseForm();
        }

        return BlocBuilder<EmployeesBloc, EmployeesState>(
          builder: (context, empState) {
            if (empState.status == EmployeesStatus.loading ||
                empState.status == EmployeesStatus.initial) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.text),
              );
            }

            final user = sl<AuthSession>().user;
            final id = user?.employeeId?.trim();
            Employee? me;
            if (id != null && id.isNotEmpty) {
              for (final e in empState.employees) {
                if (e.employeeId == id) {
                  me = e;
                  break;
                }
              }
            }

            if (me == null) {
              return const MyDetailsPage();
            }

            return _DashboardScroll(employee: me);
          },
        );
      },
    );
  }
}

class _DashboardScroll extends StatelessWidget {
  const _DashboardScroll({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;
    final dateFormat = AppDates.compact;

    final identity = EmployeeDetailSection(
      title: 'Identity',
      isDesktop: isDesktop,
      children: [
        EmployeeDetailField(label: 'Employee ID', value: employee.employeeId),
        EmployeeDetailField(
          label: 'Employee name',
          value: employee.employeeName,
        ),
        EmployeeDetailField(
          label: 'Active',
          value: employee.isActive ? 'Yes' : 'No',
        ),
        EmployeeDetailField(label: 'Location', value: employee.location),
      ],
    );

    final role = EmployeeDetailSection(
      title: 'Role & allocation',
      isDesktop: isDesktop,
      children: [
        EmployeeDetailField(label: 'Client', value: employee.client),
        EmployeeDetailField(label: 'Designation', value: employee.designation),
        EmployeeDetailField(label: 'Department', value: employee.department),
        EmployeeDetailField(label: 'Grade', value: employee.grade),
        EmployeeDetailField(
          label: 'Date of joining',
          value: dateFormat.format(employee.dateOfJoining),
        ),
      ],
    );

    final compensation = EmployeeDetailSection(
      title: 'Compensation',
      isDesktop: isDesktop,
      trailing: TextButton(
        onPressed: () => context.go(
          AppRoutes.employeeCompensation(employee.employeeId),
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.highlight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Breakdown',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.highlight,
              ),
        ),
      ),
      children: [
        EmployeeDetailField(
          label: 'Annual CTC',
          value: MoneyFormat.format(employee.annualCtc),
        ),
        EmployeeDetailField(
          label: 'Monthly CTC',
          value: MoneyFormat.format(employee.monthlyCtc),
        ),
        EmployeeDetailField(
          label: 'Medical insurance',
          value: MoneyFormat.format(employee.medicalInsurance),
        ),
        EmployeeDetailField(
          label: 'Retention amount',
          value: MoneyFormat.format(employee.retentionAmount),
        ),
      ],
    );

    final compliance = EmployeeDetailSection(
      title: 'Compliance & bank',
      isDesktop: isDesktop,
      children: [
        EmployeeDetailField(
          label: 'PF applicable',
          value: employee.pfApplicable ? 'Yes' : 'No',
        ),
        EmployeeDetailField(
          label: 'PT applicable',
          value: employee.ptApplicable ? 'Yes' : 'No',
        ),
        EmployeeDetailField(label: 'PAN', value: employee.pan),
        EmployeeDetailField(label: 'UAN', value: employee.uan),
        EmployeeDetailField(label: 'Bank A/C', value: employee.bankAccount),
        EmployeeDetailField(label: 'IFSC', value: employee.ifsc),
      ],
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(horizontal, isDesktop ? 12 : 8, horizontal, 32),
      children: [
        EmployeeDetailSectionRow(
          isDesktop: isDesktop,
          left: identity,
          right: role,
        ),
        const SizedBox(height: 12),
        EmployeeDetailSectionRow(
          isDesktop: isDesktop,
          left: compensation,
          right: compliance,
        ),
        const SizedBox(height: 20),
        _SectionHeading('Salary slip'),
        const SizedBox(height: 10),
        _SalarySlipCard(employee: employee),
        const SizedBox(height: 20),
        _ExpensesSection(isDesktop: isDesktop),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.highlight,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _SalarySlipCard extends StatelessWidget {
  const _SalarySlipCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);

    return BlocConsumer<PayrollBloc, PayrollState>(
      listenWhen: (prev, next) =>
          prev.errorMessage != next.errorMessage && next.errorMessage != null,
      listener: (context, state) {
        final message = state.errorMessage;
        if (message != null) {
          showAppMessageDialog(context, message: message);
        }
      },
      builder: (context, state) {
        final generating = state.status == PayrollStatus.generating;
        final monthLabel = DateFormat('MMMM yyyy').format(
          DateTime(state.year, state.month),
        );

        return AppListCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      monthLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 14,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: generating
                        ? null
                        : () => _pickMonth(context, state),
                    child: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment:
                    isDesktop ? Alignment.centerRight : Alignment.center,
                child: SizedBox(
                  width: isDesktop ? 200 : double.infinity,
                  child: AppButton(
                    label: generating ? 'Downloading…' : 'Download slip',
                    expand: true,
                    isLoading: generating,
                    enabled: !generating && state.employees.isNotEmpty,
                    onPressed: () => context
                        .read<PayrollBloc>()
                        .add(const PayrollDownloadSelected()),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickMonth(BuildContext context, PayrollState state) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(state.year, state.month),
      firstDate: DateTime(now.year - 5, 1),
      lastDate: DateTime(now.year + 1, 12),
      helpText: 'Select payroll month',
    );
    if (picked == null || !context.mounted) return;
    context.read<PayrollBloc>().add(
          PayrollMonthChanged(month: picked.month, year: picked.year),
        );
  }
}

class _ExpensesSection extends StatefulWidget {
  const _ExpensesSection({required this.isDesktop});

  final bool isDesktop;

  @override
  State<_ExpensesSection> createState() => _ExpensesSectionState();
}

class _ExpensesSectionState extends State<_ExpensesSection> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isDesktop = widget.isDesktop;
    final dateFormat = DateFormat('dd MMM yyyy');
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<ExpensesBloc, ExpensesState>(
      builder: (context, state) {
        if (state.status == ExpensesStatus.loading ||
            state.status == ExpensesStatus.initial) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.text),
            ),
          );
        }

        final expenses = state.expenses.where((e) {
          final q = _query.trim().toLowerCase();
          if (q.isEmpty) return true;
          return e.madeAtForSearch(q);
        }).toList();

        final newExpense = AppButton(
          label: 'New expense',
          expand: !isDesktop,
          onPressed: () =>
              context.read<ExpensesBloc>().add(const ExpenseFormOpened()),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: _SectionHeading('Expense')),
                if (isDesktop) ...[
                  const SizedBox(width: 12),
                  newExpense,
                ],
              ],
            ),
            const SizedBox(height: 10),
            AppListSearchField(
              hintText: 'Search expenses…',
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            if (state.expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No expenses yet.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              )
            else if (expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No matching expenses.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              )
            else
              ...[
                for (var i = 0; i < expenses.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final expense = expenses[i];
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
                ],
              ],
            if (!isDesktop) ...[
              const SizedBox(height: 16),
              newExpense,
            ],
          ],
        );
      },
    );
  }
}

extension on Expense {
  bool madeAtForSearch(String q) {
    return madeFor.toLowerCase().contains(q) ||
        paidFrom.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q) ||
        amount.toString().contains(q);
  }
}

class _DashboardExpenseForm extends StatefulWidget {
  const _DashboardExpenseForm();

  @override
  State<_DashboardExpenseForm> createState() => _DashboardExpenseFormState();
}

class _DashboardExpenseFormState extends State<_DashboardExpenseForm> {
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

    return BlocConsumer<ExpensesBloc, ExpensesState>(
      listenWhen: (prev, next) =>
          prev.status != next.status && next.status == ExpensesStatus.success,
      listener: (context, state) async {
        await showAppMessageDialog(context, message: 'Expense saved');
      },
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
