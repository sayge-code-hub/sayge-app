import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
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

class _ManageClientsBody extends StatelessWidget {
  const _ManageClientsBody({
    required this.embedded,
    this.onBack,
    this.onAddClient,
  });

  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onAddClient;

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

              return ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  embedded ? (isDesktop ? 12 : 8) : 16,
                  horizontal,
                  24,
                ),
                itemCount: state.clients.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final client = state.clients[index];
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      client.name,
                      style: textTheme.titleMedium?.copyWith(fontSize: 14),
                    ),
                  );
                },
              );
            },
          ),
        ),
        EmployeeStickyActions(
          children: [
            OutlinedButton(
              onPressed: onBack,
              child: const Text('Back'),
            ),
            AppButton(
              label: 'Add client',
              expand: false,
              onPressed: onAddClient,
            ),
          ],
        ),
      ],
    );
  }
}
