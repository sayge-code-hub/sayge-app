import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/employee.dart';
import '../bloc/employees/employees_bloc.dart';

class EmployeesPage extends StatelessWidget {
  const EmployeesPage({
    super.key,
    required this.user,
    this.embedded = false,
    this.onAddEmployee,
    this.onEmployeeSelected,
  });

  final User user;
  final bool embedded;
  final VoidCallback? onAddEmployee;
  final ValueChanged<Employee>? onEmployeeSelected;

  @override
  Widget build(BuildContext context) {
    final content = _EmployeesBody(onEmployeeSelected: onEmployeeSelected);

    if (embedded) {
      return content;
    }

    return BlocProvider(
      create: (_) => sl<EmployeesBloc>()..add(const EmployeesRequested()),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Employees'),
          actions: [
            IconButton(
              tooltip: 'Add employee',
              onPressed: onAddEmployee,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: content,
      ),
    );
  }
}

class _EmployeesBody extends StatelessWidget {
  const _EmployeesBody({this.onEmployeeSelected});

  final ValueChanged<Employee>? onEmployeeSelected;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);

    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, state) {
        if (state.status == EmployeesStatus.loading ||
            state.status == EmployeesStatus.initial) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        if (state.status == EmployeesStatus.failure) {
          return Center(
            child: Text(
              state.errorMessage ?? 'Failed to load employees',
              style: const TextStyle(color: AppColors.error),
            ),
          );
        }

        if (state.employees.isEmpty) {
          return const Center(
            child: Text('No employees yet. Add your first employee.'),
          );
        }

        if (isDesktop) {
          return EmployeesTable(
            employees: state.employees,
            onEmployeeSelected: onEmployeeSelected,
          );
        }

        return _EmployeesMobileList(
          employees: state.employees,
          onEmployeeSelected: onEmployeeSelected,
        );
      },
    );
  }
}

/// Desktop table inspired by payroll consoles (checkboxes, avatars, pagination).
class EmployeesTable extends StatefulWidget {
  const EmployeesTable({
    super.key,
    required this.employees,
    this.onEmployeeSelected,
  });

  final List<Employee> employees;
  final ValueChanged<Employee>? onEmployeeSelected;

  @override
  State<EmployeesTable> createState() => _EmployeesTableState();
}

class _EmployeesTableState extends State<EmployeesTable> {
  final int _pageSize = 10;
  int _page = 0;
  final Set<String> _selectedIds = {};
  String? _sortColumn;
  bool _sortAscending = true;

  List<Employee> get _sorted {
    final list = [...widget.employees];
    int compare(Employee a, Employee b) {
      switch (_sortColumn) {
        case 'name':
          return a.employeeName.compareTo(b.employeeName);
        case 'doj':
          return a.dateOfJoining.compareTo(b.dateOfJoining);
        case 'status':
          return a.isActive == b.isActive ? 0 : (a.isActive ? -1 : 1);
        case 'role':
          return a.designation.compareTo(b.designation);
        case 'ctc':
          return a.annualCtc.compareTo(b.annualCtc);
        case 'client':
          return a.client.compareTo(b.client);
        default:
          return a.employeeId.compareTo(b.employeeId);
      }
    }

    list.sort((a, b) => _sortAscending ? compare(a, b) : compare(b, a));
    return list;
  }

  List<Employee> get _pageItems {
    final sorted = _sorted;
    final start = _page * _pageSize;
    if (start >= sorted.length) return const [];
    final end = (start + _pageSize).clamp(0, sorted.length);
    return sorted.sublist(start, end);
  }

  int get _pageCount {
    if (widget.employees.isEmpty) return 1;
    return ((widget.employees.length - 1) / _pageSize).floor() + 1;
  }

  void _toggleSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = AppDates.medium;
    final pageItems = _pageItems;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 32),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Filter'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.sizeOf(context).width - 248 - 64,
                        ),
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowHeight: 48,
                            dataRowMinHeight: 56,
                            dataRowMaxHeight: 64,
                            horizontalMargin: 20,
                            columnSpacing: 28,
                            dividerThickness: 0.6,
                            headingTextStyle: textTheme.labelLarge?.copyWith(
                              color: AppColors.textLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                            dataTextStyle: textTheme.bodyLarge?.copyWith(
                              color: AppColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                            columns: [
                              DataColumn(
                                label: Checkbox(
                                  value: pageItems.isNotEmpty &&
                                      pageItems.every(
                                        (e) =>
                                            _selectedIds.contains(e.employeeId),
                                      ),
                                  tristate: true,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                    width: 1.5,
                                  ),
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedIds.addAll(
                                          pageItems.map((e) => e.employeeId),
                                        );
                                      } else {
                                        for (final e in pageItems) {
                                          _selectedIds.remove(e.employeeId);
                                        }
                                      }
                                    });
                                  },
                                ),
                              ),
                              _sortableHeader('NAME', 'name'),
                              _sortableHeader('DATE EMPLOYED', 'doj'),
                              _sortableHeader('STATUS', 'status'),
                              _sortableHeader('ROLE', 'role'),
                              _sortableHeader('CLIENT', 'client'),
                              _sortableHeader('ANNUAL CTC', 'ctc'),
                              const DataColumn(label: Text('LOCATION')),
                            ],
                            rows: pageItems.map((employee) {
                              final selected =
                                  _selectedIds.contains(employee.employeeId);
                              return DataRow(
                                selected: selected,
                                cells: [
                                  DataCell(
                                    Checkbox(
                                      value: selected,
                                      side: const BorderSide(
                                        color: AppColors.border,
                                        width: 1.5,
                                      ),
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedIds
                                                .add(employee.employeeId);
                                          } else {
                                            _selectedIds
                                                .remove(employee.employeeId);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 15,
                                          backgroundColor: AppColors.text
                                              .withValues(alpha: 0.08),
                                          child: Text(
                                            _initials(employee.employeeName),
                                            style: textTheme.labelLarge
                                                ?.copyWith(
                                              fontSize: 11,
                                              color: AppColors.text,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          employee.employeeName,
                                          style: textTheme.titleMedium
                                              ?.copyWith(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    onTap: () =>
                                        widget.onEmployeeSelected?.call(employee),
                                  ),
                                  DataCell(
                                    Text(
                                      dateFormat
                                          .format(employee.dateOfJoining),
                                    ),
                                    onTap: () =>
                                        widget.onEmployeeSelected?.call(employee),
                                  ),
                                  DataCell(
                                    Text(
                                      employee.isActive ? 'Active' : 'Inactive',
                                      style: textTheme.labelLarge?.copyWith(
                                        fontSize: 13,
                                        color: employee.isActive
                                            ? AppColors.success
                                            : AppColors.textLight,
                                      ),
                                    ),
                                    onTap: () =>
                                        widget.onEmployeeSelected?.call(employee),
                                  ),
                                  DataCell(
                                    Text(employee.designation),
                                    onTap: () =>
                                        widget.onEmployeeSelected?.call(employee),
                                  ),
                                  DataCell(
                                    Text(employee.client),
                                    onTap: () =>
                                        widget.onEmployeeSelected?.call(employee),
                                  ),
                                  DataCell(
                                    Text(
                                      MoneyFormat.format(employee.annualCtc),
                                      style: textTheme.titleMedium
                                          ?.copyWith(fontSize: 13),
                                    ),
                                    onTap: () =>
                                        widget.onEmployeeSelected?.call(employee),
                                  ),
                                  DataCell(
                                    Text(employee.location),
                                    onTap: () =>
                                        widget.onEmployeeSelected?.call(employee),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _Pagination(
                        page: _page,
                        pageCount: _pageCount,
                        onChanged: (page) => setState(() => _page = page),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataColumn _sortableHeader(String label, String key) {
    final active = _sortColumn == key;
    return DataColumn(
      label: InkWell(
        onTap: () => _toggleSort(key),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 4),
            Icon(
              active
                  ? (_sortAscending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 14,
              color: active ? AppColors.highlight : AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.pageCount,
    required this.onChanged,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < pageCount; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == page ? AppColors.highlight : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${i + 1}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                      color:
                          i == page ? AppColors.background : AppColors.text,
                    ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmployeesMobileList extends StatelessWidget {
  const _EmployeesMobileList({
    required this.employees,
    this.onEmployeeSelected,
  });

  final List<Employee> employees;
  final ValueChanged<Employee>? onEmployeeSelected;

  @override
  Widget build(BuildContext context) {
    final dateFormat = AppDates.short;
    final textTheme = Theme.of(context).textTheme;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: employees.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final employee = employees[index];
        return InkWell(
          onTap: () => onEmployeeSelected?.call(employee),
          borderRadius: BorderRadius.circular(12),
          child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.text.withValues(alpha: 0.08),
                    child: Text(
                      employee.employeeName.isEmpty
                          ? '?'
                          : employee.employeeName[0].toUpperCase(),
                      style: textTheme.labelLarge?.copyWith(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      employee.employeeName,
                      style: textTheme.titleMedium?.copyWith(fontSize: 14),
                    ),
                  ),
                  Text(
                    employee.isActive ? 'Active' : 'Inactive',
                    style: textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                      color: employee.isActive
                          ? AppColors.success
                          : AppColors.textLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                employee.designation,
                style: textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: AppColors.text,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${employee.client} · ${dateFormat.format(employee.dateOfJoining)}',
                style: textTheme.bodyMedium?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                MoneyFormat.format(employee.annualCtc),
                style: textTheme.titleMedium?.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}


