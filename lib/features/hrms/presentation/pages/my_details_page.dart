import 'package:flutter/material.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';

/// Shown when an employee account has no linked `users.employee_id`.
class MyDetailsPage extends StatelessWidget {
  const MyDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 16,
        isDesktop ? 24 : 16,
        isDesktop ? 32 : 16,
        24,
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Your profile is not linked to an employee record yet. '
            'Ask an owner to link your account, then you can view your '
            'details, compensation, and salary slips here.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textLight,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}
