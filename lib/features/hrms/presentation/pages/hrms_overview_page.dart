import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/employees/employees_bloc.dart';
import '../widgets/employee_stat_cards.dart';

/// HRMS landing: stats cards only.
class HrmsOverviewPage extends StatelessWidget {
  const HrmsOverviewPage({super.key});

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
              state.errorMessage ?? 'Failed to load overview',
              style: const TextStyle(color: AppColors.error),
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 16,
            isDesktop ? 12 : 8,
            isDesktop ? 32 : 16,
            32,
          ),
          children: [
            EmployeeStatCards(employees: state.employees),
          ],
        );
      },
    );
  }
}
