import 'package:flutter/material.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/employee.dart';

class EmployeeStatCards extends StatelessWidget {
  const EmployeeStatCards({super.key, required this.employees});

  final List<Employee> employees;

  @override
  Widget build(BuildContext context) {
    final active = employees.where((e) => e.isActive).length;
    final clients = employees.map((e) => e.client).toSet().length;
    final isCompact = Breakpoints.isCompact(context);

    final stats = [
      (
        label: 'Employees',
        value: '${employees.length}',
        hint: '$active active',
      ),
      (
        label: 'Active',
        value: '$active',
        hint: '${employees.length - active} inactive',
      ),
      (
        label: 'Clients',
        value: '$clients',
        hint: 'Allocated accounts',
      ),
    ];

    if (isCompact) {
      return Column(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _StatTile(
              label: stats[i].label,
              value: stats[i].value,
              hint: stats[i].hint,
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(
            child: _StatTile(
              label: stats[i].label,
              value: stats[i].value,
              hint: stats[i].hint,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: textTheme.headlineMedium?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
