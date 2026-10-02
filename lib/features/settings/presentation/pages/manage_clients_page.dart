import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../hrms/presentation/widgets/employee_form_layout.dart';
import '../bloc/clients/clients_bloc.dart';

class ManageClientsPage extends StatelessWidget {
  const ManageClientsPage({
    super.key,
    this.embedded = false,
    this.onBack,
    this.onAddClient,
  });

  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onAddClient;

  @override
  Widget build(BuildContext context) {
    final content = _ManageClientsBody(
      embedded: embedded,
      onBack: onBack,
      onAddClient: onAddClient,
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Manage clients',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        leading: onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
      ),
      body: content,
    );
  }
}

class _ManageClientsBody extends StatefulWidget {
  const _ManageClientsBody({
    required this.embedded,
    this.onBack,
    this.onAddClient,
  });

  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onAddClient;

  @override
  State<_ManageClientsBody> createState() => _ManageClientsBodyState();
}

class _ManageClientsBodyState extends State<_ManageClientsBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final textTheme = Theme.of(context).textTheme;
    final horizontal = isDesktop ? 32.0 : 16.0;

    return Column(
      children: [
        Expanded(
          child: BlocBuilder<ClientsBloc, ClientsState>(
            builder: (context, state) {
              if (state.status == ClientsStatus.loading ||
                  state.status == ClientsStatus.initial) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.text),
                );
              }

              if (state.status == ClientsStatus.failure &&
                  state.clients.isEmpty) {
                return Center(
                  child: Text(
                    state.errorMessage ?? 'Failed to load clients',
                    style:
                        textTheme.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                );
              }

              if (state.clients.isEmpty) {
                return Center(
                  child: Text(
                    'No clients yet.',
                    style: textTheme.bodyMedium?.copyWith(fontSize: 13),
                  ),
                );
              }

              final q = _query.trim().toLowerCase();
              final clients = q.isEmpty
                  ? state.clients
                  : state.clients.where((c) {
                      return c.displayLabel.toLowerCase().contains(q) ||
                          c.gstin.toLowerCase().contains(q) ||
                          c.name.toLowerCase().contains(q);
                    }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      widget.embedded ? (isDesktop ? 12 : 8) : 16,
                      horizontal,
                      12,
                    ),
                    child: AppListSearchField(
                      hintText: 'Search clients…',
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  Expanded(
                    child: clients.isEmpty
                        ? Center(
                            child: Text(
                              'No matching clients.',
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
                            itemCount: clients.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final client = clients[index];
                              return AppListCard(
                                borderRadius: 12,
                                padding: AppListCard.sectionPadding,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      client.displayLabel,
                                      style: textTheme.titleMedium
                                          ?.copyWith(fontSize: 14),
                                    ),
                                    if (client.gstin.trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'GSTIN ${client.gstin}',
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
            AppButton(
              label: 'Add client',
              onPressed: widget.onAddClient,
            ),
          ],
        ),
      ],
    );
  }
}
