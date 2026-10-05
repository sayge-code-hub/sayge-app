import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../hrms/presentation/widgets/employee_form_layout.dart';
import '../../domain/entities/client.dart';
import '../bloc/clients/clients_bloc.dart';
import '../widgets/client_documents_section.dart';

class ClientDetailPage extends StatelessWidget {
  const ClientDetailPage({
    super.key,
    required this.clientId,
    this.embedded = false,
    this.onBack,
    this.onEdit,
  });

  final String clientId;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientsBloc, ClientsState>(
      builder: (context, state) {
        Client? client;
        for (final item in state.clients) {
          if (item.id == clientId) {
            client = item;
            break;
          }
        }

        if (client == null &&
            (state.status == ClientsStatus.loading ||
                state.status == ClientsStatus.initial)) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        if (client == null) {
          return Center(
            child: Text(
              'Client not found.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          );
        }

        return _ClientDetailBody(
          client: client,
          embedded: embedded,
          onBack: onBack,
          onEdit: onEdit,
        );
      },
    );
  }
}

class _ClientDetailBody extends StatelessWidget {
  const _ClientDetailBody({
    required this.client,
    required this.embedded,
    this.onBack,
    this.onEdit,
  });

  final Client client;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;

    final details = EmployeeDetailSection(
      title: 'Client details',
      isDesktop: isDesktop,
      children: [
        EmployeeDetailField(label: 'Company name', value: client.name),
        EmployeeDetailField(label: 'Contact name', value: client.contactName),
        EmployeeDetailField(label: 'Vendor code', value: client.vendorCode),
        EmployeeDetailField(label: 'Entity code', value: client.entityCode),
        EmployeeDetailField(label: 'GSTIN', value: client.gstin),
        EmployeeDetailField(
          label: 'Status',
          value: client.isActive ? 'Active' : 'Inactive',
        ),
        EmployeeDetailField(label: 'Address', value: client.address),
      ],
    );

    final body = Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              embedded ? (isDesktop ? 12 : 8) : 16,
              horizontal,
              24,
            ),
            children: [
              details,
              const SizedBox(height: 12),
              ClientDocumentsSection(
                clientId: client.id,
                clientName: client.name,
                enabled: false,
              ),
            ],
          ),
        ),
        EmployeeStickyActions(
          children: [
            if (onBack != null)
              OutlinedButton(
                onPressed: onBack,
                child: const Text('Back'),
              ),
            if (onEdit != null)
              AppButton(
                label: 'Edit',
                onPressed: onEdit,
              ),
          ],
        ),
      ],
    );

    if (embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          client.displayLabel,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        leading: onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
      ),
      body: body,
    );
  }
}
