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

  Future<void> _confirmDelete(Client client) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text('Delete client'),
          content: Text(
            'Delete ${client.displayLabel}? Linked employees will keep their '
            'records but lose this client link.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    context.read<ClientsBloc>().add(ClientDeleted(client.id));
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
        showAppMessageDialog(
          context,
          title: 'Clients',
          message: message,
        );
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
                      style: textTheme.bodyMedium
                          ?.copyWith(color: AppColors.error),
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
                                  color: client.isActive
                                      ? AppColors.background
                                      : AppColors.surfaceMuted,
                                  onTap: busy
                                      ? null
                                      : () => widget.onOpenClient
                                          ?.call(client.id),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                if (!client.isActive) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
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
                                                        color: AppColors.error,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (client
                                                .contactName
                                                .trim()
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                client.contactName,
                                                style: textTheme.bodyMedium
                                                    ?.copyWith(
                                                  fontSize: 13,
                                                  color: AppColors.text,
                                                ),
                                              ),
                                            ],
                                            if (client.gstin
                                                .trim()
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                'GSTIN ${client.gstin}',
                                                style: textTheme.bodyMedium
                                                    ?.copyWith(
                                                  fontSize: 12,
                                                  color: AppColors.textLight,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      AppListIconButton(
                                        tooltip: client.isActive
                                            ? 'Deactivate'
                                            : 'Activate',
                                        iconSize: 15,
                                        buttonSize: 28,
                                        icon: client.isActive
                                            ? Icons.pause_circle_outline
                                            : Icons.play_circle_outline,
                                        onPressed: busy
                                            ? null
                                            : () => context
                                                .read<ClientsBloc>()
                                                .add(
                                                  ClientActiveToggled(
                                                    clientId: client.id,
                                                    isActive: !client.isActive,
                                                  ),
                                                ),
                                      ),
                                      const SizedBox(width: 4),
                                      AppListIconButton(
                                        tooltip: 'Delete',
                                        iconSize: 15,
                                        buttonSize: 28,
                                        icon: Icons.delete_outline,
                                        onPressed: busy
                                            ? null
                                            : () => _confirmDelete(client),
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
              AppButton(
                label: 'Add client',
                onPressed: widget.onAddClient,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
