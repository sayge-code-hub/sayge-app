import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../injection_container.dart';
import '../../../hrms/presentation/widgets/employee_form_layout.dart';
import '../../domain/entities/settings_entities.dart';
import '../bloc/ledger/ledger_bloc.dart';

class LedgerPage extends StatelessWidget {
  const LedgerPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LedgerBloc>()..add(const LedgerStarted()),
      child: _LedgerBody(onBack: onBack),
    );
  }
}

class _LedgerBody extends StatefulWidget {
  const _LedgerBody({this.onBack});

  final VoidCallback? onBack;

  @override
  State<_LedgerBody> createState() => _LedgerBodyState();
}

class _LedgerBodyState extends State<_LedgerBody> {
  String _query = '';

  List<ActivityLogEntry> _filter(List<ActivityLogEntry> entries) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries.where((e) {
      return e.summary.toLowerCase().contains(q) ||
          e.tableName.toLowerCase().contains(q) ||
          e.action.toLowerCase().contains(q) ||
          e.recordId.toLowerCase().contains(q) ||
          (e.actorEmail ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;
    final textTheme = Theme.of(context).textTheme;
    final stamp = DateFormat('dd MMM yyyy · HH:mm');

    return Column(
      children: [
        Expanded(
          child: BlocBuilder<LedgerBloc, LedgerState>(
            builder: (context, state) {
              if (state.status == LedgerStatus.initial ||
                  state.status == LedgerStatus.loading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.text),
                );
              }
              if (state.status == LedgerStatus.failure &&
                  state.entries.isEmpty) {
                return Center(
                  child: Text(
                    state.errorMessage ?? 'Failed to load ledger',
                    style:
                        textTheme.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                );
              }
              if (state.entries.isEmpty) {
                return Center(
                  child: Text(
                    'No activity yet.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                );
              }

              final entries = _filter(state.entries);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 12),
                    child: AppListSearchField(
                      hintText: 'Search ledger…',
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  Expanded(
                    child: entries.isEmpty
                        ? Center(
                            child: Text(
                              'No matching activity.',
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
                            itemCount: entries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              return AppListCard(
                                borderRadius: 12,
                                padding: AppListCard.sectionPadding,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _ActionChip(action: entry.action),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            entry.tableName
                                                .replaceAll('_', ' '),
                                            style: textTheme.titleMedium
                                                ?.copyWith(fontSize: 13),
                                          ),
                                        ),
                                        Text(
                                          stamp.format(
                                            entry.occurredAt.toLocal(),
                                          ),
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontSize: 11,
                                            color: AppColors.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      entry.summary,
                                      style: textTheme.bodyMedium
                                          ?.copyWith(fontSize: 13),
                                    ),
                                    if ((entry.actorEmail ?? '')
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        entry.actorEmail!,
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontSize: 12,
                                          color: AppColors.textLight,
                                        ),
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
            OutlinedButton(
              onPressed: () =>
                  context.read<LedgerBloc>().add(const LedgerStarted()),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.action});

  final String action;

  @override
  Widget build(BuildContext context) {
    final label = action.toUpperCase();
    final color = switch (label) {
      'INSERT' => AppColors.success,
      'DELETE' => AppColors.error,
      _ => AppColors.textLight,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 10,
              letterSpacing: 0.4,
              color: color,
            ),
      ),
    );
  }
}
