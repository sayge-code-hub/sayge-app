import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../hrms/presentation/widgets/employee_avatar.dart';
import '../../../hrms/presentation/widgets/employee_form_layout.dart';
import '../../domain/entities/client.dart';
import '../bloc/clients/clients_bloc.dart';

class ManageClientsPage extends StatelessWidget {
  const ManageClientsPage({
    super.key,
    this.embedded = false,
    this.onBack,
    this.onAddClient,
    this.onOpenClient,
  });

  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onAddClient;
  final ValueChanged<String>? onOpenClient;

  @override
  Widget build(BuildContext context) {
    final content = _ManageClientsBody(
      embedded: embedded,
      onBack: onBack,
      onAddClient: onAddClient,
      onOpenClient: onOpenClient,
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
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
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
    this.onOpenClient,
  });

  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onAddClient;
  final ValueChanged<String>? onOpenClient;

  @override
  State<_ManageClientsBody> createState() => _ManageClientsBodyState();
}

class _ManageClientsBodyState extends State<_ManageClientsBody> {
  String _query = '';

  Client _representative(List<Client> group) {
    for (final client in group) {
      if ((client.logoUrl ?? '').trim().isNotEmpty) return client;
    }
    return Client.uniqueByCompany(group).first;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final textTheme = Theme.of(context).textTheme;
    final horizontal = isDesktop ? 32.0 : 16.0;

    return BlocListener<ClientsBloc, ClientsState>(
      listenWhen: (prev, next) =>
          prev.errorMessage != next.errorMessage && next.errorMessage != null,
      listener: (context, state) {
        final message = state.errorMessage;
        if (message == null) return;
        showAppMessageDialog(context, title: 'Clients', message: message);
      },
      child: Column(
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
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                      ),
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
                final grouped = <String, List<Client>>{};
                for (final client in state.clients) {
                  final key = client.companyKey;
                  if (key.isEmpty) continue;
                  final matches =
                      q.isEmpty ||
                      client.name.toLowerCase().contains(q) ||
                      client.contactName.toLowerCase().contains(q) ||
                      client.gstin.toLowerCase().contains(q);
                  if (!matches) continue;
                  grouped.putIfAbsent(key, () => []).add(client);
                }
                final companies = grouped.values.toList()
                  ..sort(
                    (a, b) => a.first.name.toLowerCase().compareTo(
                      b.first.name.toLowerCase(),
                    ),
                  );

                final busy = state.status == ClientsStatus.saving;

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
                      child: companies.isEmpty
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
                              itemCount: companies.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final group = companies[index];
                                final client = _representative(group);
                                final gstin = group
                                    .map((item) => item.gstin.trim())
                                    .firstWhere(
                                      (value) => value.isNotEmpty,
                                      orElse: () => '',
                                    );
                                final active = group.any(
                                  (item) => item.isActive,
                                );
                                return AppListCard(
                                  borderRadius: 12,
                                  padding: AppListCard.sectionPadding,
                                  color: active
                                      ? AppColors.background
                                      : AppColors.surfaceMuted,
                                  onTap: busy
                                      ? null
                                      : () => widget.onOpenClient?.call(
                                          client.id,
                                        ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      EmployeeAvatar(
                                        name: client.name,
                                        photoUrl: client.logoUrl,
                                        radius: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    client.name,
                                                    style: textTheme.titleMedium
                                                        ?.copyWith(
                                                          fontSize: 14,
                                                        ),
                                                  ),
                                                ),
                                                if (!active) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.error
                                                          .withValues(
                                                            alpha: 0.12,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      'Inactive',
                                                      style: textTheme
                                                          .labelLarge
                                                          ?.copyWith(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                AppColors.error,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (gstin.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                'GSTIN $gstin',
                                                style: textTheme.bodyMedium
                                                    ?.copyWith(
                                                      fontSize: 12,
                                                      color:
                                                          AppColors.textLight,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
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
              AppButton(label: 'Add client', onPressed: widget.onAddClient),
            ],
          ),
        ],
      ),
    );
  }
}
