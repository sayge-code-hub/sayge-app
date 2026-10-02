import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../injection_container.dart';
import '../../../hrms/presentation/widgets/employee_form_layout.dart';
import '../../domain/entities/settings_entities.dart';
import '../bloc/roles/roles_bloc.dart';

class RolesPage extends StatelessWidget {
  const RolesPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RolesBloc>()..add(const RolesStarted()),
      child: _RolesBody(onBack: onBack),
    );
  }
}

class _RolesBody extends StatefulWidget {
  const _RolesBody({this.onBack});

  final VoidCallback? onBack;

  @override
  State<_RolesBody> createState() => _RolesBodyState();
}

class _RolesBodyState extends State<_RolesBody> {
  String _query = '';

  List<AppRole> _filter(List<AppRole> roles) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return roles;
    return roles.where((r) {
      return r.label.toLowerCase().contains(q) ||
          r.code.toLowerCase().contains(q) ||
          r.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: BlocBuilder<RolesBloc, RolesState>(
            builder: (context, state) {
              if (state.status == RolesStatus.initial ||
                  state.status == RolesStatus.loading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.text),
                );
              }
              if (state.status == RolesStatus.failure && state.roles.isEmpty) {
                return Center(
                  child: Text(
                    state.errorMessage ?? 'Failed to load roles',
                    style:
                        textTheme.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                );
              }
              if (state.roles.isEmpty) {
                return Center(
                  child: Text(
                    'No roles configured.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                );
              }

              final roles = _filter(state.roles);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 12),
                    child: AppListSearchField(
                      hintText: 'Search roles…',
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  Expanded(
                    child: roles.isEmpty
                        ? Center(
                            child: Text(
                              'No matching roles.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textLight,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              0,
                              horizontal,
                              24,
                            ),
                            itemCount: roles.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final role = roles[index];
                              return AppListCard(
                                borderRadius: 12,
                                padding: AppListCard.sectionPadding,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            role.label,
                                            style: textTheme.titleMedium
                                                ?.copyWith(fontSize: 14),
                                          ),
                                        ),
                                        Text(
                                          role.isActive ? 'Active' : 'Inactive',
                                          style: textTheme.labelLarge?.copyWith(
                                            fontSize: 12,
                                            color: role.isActive
                                                ? AppColors.success
                                                : AppColors.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      role.code,
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontSize: 12,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                    if (role.description
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        role.description,
                                        style: textTheme.bodyMedium
                                            ?.copyWith(fontSize: 13),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        EmployeeStickyActions(
          children: [
            OutlinedButton(
              onPressed: widget.onBack,
              child: const Text('Back'),
            ),
          ],
        ),
      ],
    );
  }
}
